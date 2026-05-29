import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../models/intervention.dart';
import '../../models/carnet_entretien.dart';
import '../../models/facture.dart';
import '../../services/intervention_service.dart';
import '../../services/carnet_service.dart';
import '../../services/facture_service.dart';
import '../../services/ai_service.dart';

class CompleteInterventionScreen extends StatefulWidget {
  final Intervention intervention;

  const CompleteInterventionScreen({super.key, required this.intervention});

  @override
  State<CompleteInterventionScreen> createState() => _CompleteInterventionScreenState();
}

class _CompleteInterventionScreenState extends State<CompleteInterventionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _kmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isScanning = false;

  final List<FactureItem> _factureItems = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill with estimated price if available
    if (widget.intervention.prixEstime > 0) {
      _priceCtrl.text = widget.intervention.prixEstime.toInt().toString();
    }
    // Pre-fill with current vehicle mileage if known
    if (widget.intervention.kilometrageCompteur != null) {
      _kmCtrl.text = widget.intervention.kilometrageCompteur.toString();
    }
  }

  Future<void> _scanInvoice() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    
    if (image == null) return;

    setState(() => _isScanning = true);

    try {
      final Uint8List bytes = await image.readAsBytes();
      final data = await AIService.analyzeInvoice(bytes);

      if (data != null && mounted) {
        setState(() {
          if (data['kilometrage'] != null) {
            _kmCtrl.text = data['kilometrage'].toString();
          }
          if (data['total_price'] != null) {
            _priceCtrl.text = data['total_price'].toString();
          }
          if (data['items'] != null && data['items'] is List) {
            _factureItems.clear();
            for (var item in data['items']) {
              _factureItems.add(FactureItem(
                description: item['description'] ?? 'Inconnu',
                prix: (item['price'] as num?)?.toDouble() ?? 0.0,
                categorie: _mapAiCategory(item['category']),
              ));
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analyse AI terminée avec succès !'), backgroundColor: Colors.purple),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'analyser l\'image. Vérifiez votre clé API.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur scan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  String _mapAiCategory(dynamic aiCategory) {
    if (aiCategory == null) return 'PIECE';
    String cat = aiCategory.toString().toUpperCase();
    if (cat.contains('FLUIDE')) return 'FLUIDE';
    if (cat.contains('SERVICE') || cat.contains('MAIN')) return 'SERVICE';
    return 'PIECE';
  }

  void _addFactureItem() {
    final descCtrl = TextEditingController();
    final itemPriceCtrl = TextEditingController();
    String selectedCategory = 'PIECE';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter une ligne'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl, 
                  decoration: const InputDecoration(labelText: 'Description (ex: Filtre à air)')
                ),
                TextField(
                  controller: itemPriceCtrl, 
                  decoration: const InputDecoration(labelText: 'Prix (DT)'), 
                  keyboardType: TextInputType.number
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Type d\'élément'),
                  items: const [
                    DropdownMenuItem(value: 'PIECE', child: Text('Pièce de rechange')),
                    DropdownMenuItem(value: 'FLUIDE', child: Text('Liquide / Fluide')),
                    DropdownMenuItem(value: 'SERVICE', child: Text('Main d\'œuvre / Service')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCategory = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (descCtrl.text.trim().isNotEmpty && itemPriceCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _factureItems.add(FactureItem(
                      description: descCtrl.text.trim(),
                      prix: double.tryParse(itemPriceCtrl.text) ?? 0.0,
                      categorie: selectedCategory,
                    ));
                    _updateTotalPrice();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateTotalPrice() {
    double total = _factureItems.fold(0, (sum, item) => sum + item.prix);
    if (total > 0) {
      _priceCtrl.text = total.toStringAsFixed(0);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final finalPrice = double.tryParse(_priceCtrl.text) ?? 0.0;
    final currentKm = int.tryParse(_kmCtrl.text) ?? 0;

    // Strict validation: fields must not be empty or zero
    if (finalPrice <= 0 || currentKm <= 0) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir le montant total et le kilométrage avant de confirmer.'), backgroundColor: Colors.orange)
        );
        return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Mark intervention as finished
      await InterventionService.completeIntervention(
        widget.intervention, 
        finalPrice: finalPrice,
        newMileage: currentKm,
      );

      // 2. Save the detailed Invoice (Facture)
      await FactureService.saveFacture(Facture(
        id: '',
        interventionId: widget.intervention.id,
        vehicleId: widget.intervention.vehiculeId,
        mecanicienId: widget.intervention.mecanicienId ?? '',
        date: DateTime.now(),
        items: _factureItems.isNotEmpty ? _factureItems : [
          FactureItem(description: "Intervention technique", prix: finalPrice, categorie: "SERVICE")
        ],
        total: finalPrice,
      ));

      // 3. Automatically update vehicle maintenance history (Carnet)
      // Every 'PIECE' or 'FLUIDE' in the facture lines triggers a health reset
      for (var item in _factureItems) {
        if (item.categorie == 'PIECE' || item.categorie == 'FLUIDE') {
          // Derive a composantId slug from the description to track wear reset
          final compId = item.description.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
          
          await CarnetService.updateEntry(CarnetEntretien(
            id: '',
            dernierKilometrageChangement: currentKm,
            dateChangement: DateTime.now(),
            niveauUsure: 0.0,
            vehicleId: widget.intervention.vehiculeId,
            composantId: compId,
            nomComposantCustom: item.description,
            categorie: item.categorie,
          ));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention terminée avec succès !'), backgroundColor: Colors.green)
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Finaliser l\'intervention', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoSection(),
              const SizedBox(height: 24),
              _buildAiScanner(),
              const SizedBox(height: 32),
              _buildKmAndPriceSection(),
              const SizedBox(height: 32),
              _buildFactureLinesSection(),
              const SizedBox(height: 48),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiScanner() {
    return InkWell(
      onTap: _isScanning ? null : _scanInvoice,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.shade200, width: 2),
        ),
        child: Column(
          children: [
            if (_isScanning)
              const CircularProgressIndicator(color: Colors.purple)
            else ...[
              const Icon(Icons.auto_awesome, color: Colors.purple, size: 36),
              const SizedBox(height: 12),
              const Text('Scanner avec l\'IA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 16)),
              const Text('Photographiez votre facture papier pour la remplir automatiquement.', 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 12, color: Colors.purple),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_rounded, color: Color(0xFF1976D2)),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.intervention.vehiculeNom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
            ],
          ),
          const SizedBox(height: 8),
          Text('Type demandé: ${widget.intervention.typeLabel}', style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildKmAndPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Données du véhicule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 16),
        TextFormField(
          controller: _kmCtrl,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('Kilométrage actuel', Icons.speed_rounded, 'km'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Le kilométrage est obligatoire' : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('Montant Total Facturé', Icons.payments_rounded, 'DT'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Le montant total est obligatoire' : null,
        ),
      ],
    );
  }

  Widget _buildFactureLinesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Détails de la prestation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            TextButton.icon(
              onPressed: _addFactureItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        if (_factureItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucune ligne ajoutée. Saisissez manuellement ou utilisez le scan IA.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
          )
        else
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: _factureItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return ListTile(
                  title: Text(item.description, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(item.categorie, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${item.prix.toStringAsFixed(0)} DT', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red), 
                        onPressed: () {
                          setState(() {
                            _factureItems.removeAt(idx);
                            _updateTotalPrice();
                          });
                        }
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('CONFIRMER ET NOTIFIER LE CLIENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, String suffix) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
      suffixText: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2)),
    );
  }
}
