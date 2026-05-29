import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/intervention.dart';
import '../../models/carnet_entretien.dart';
import '../../models/composant.dart';
import '../../services/intervention_service.dart';
import '../../services/carnet_service.dart';
import '../../services/composant_service.dart';
import '../../services/notification_service.dart';
import '../../models/app_notification.dart';

class CompleteInterventionScreen extends StatefulWidget {
  final Intervention intervention;

  const CompleteInterventionScreen({super.key, required this.intervention});

  @override
  State<CompleteInterventionScreen> createState() => _CompleteInterventionScreenState();
}

class _MaintenanceUpdate {
  String label;
  String composantId;
  String category;
  bool isSelected = false;

  _MaintenanceUpdate({required this.label, required this.composantId, required this.category});
}

class _CompleteInterventionScreenState extends State<CompleteInterventionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _kmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _loadingComposants = true;

  List<_MaintenanceUpdate> _updates = [];

  @override
  void initState() {
    super.initState();
    _priceCtrl.text = widget.intervention.prixEstime.toInt().toString();
    _loadComposants();
  }

  Future<void> _loadComposants() async {
    try {
      final list = await ComposantService.allComposantsStream().first;
      setState(() {
        if (list.isNotEmpty) {
          _updates = list
              .where((c) => c.categorie != 'CONTROLE')
              .map((c) => _MaintenanceUpdate(
                    label: c.nom,
                    composantId: c.id,
                    category: c.categorie,
                  ))
              .toList();
        } else {
          // Fallback if DB is empty
          _updates = [
            _MaintenanceUpdate(label: 'Vidange Huile Moteur', composantId: 'oil_change', category: 'FLUIDE'),
            _MaintenanceUpdate(label: 'Pneus', composantId: 'c1', category: 'PIECE'),
            _MaintenanceUpdate(label: 'Plaquettes de frein', composantId: 'c2', category: 'PIECE'),
            _MaintenanceUpdate(label: 'Batterie', composantId: 'c3', category: 'PIECE'),
            _MaintenanceUpdate(label: 'Filtre à air', composantId: 'c4', category: 'PIECE'),
          ];
        }
        _loadingComposants = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingComposants = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final finalPrice = double.tryParse(_priceCtrl.text) ?? 0.0;
      final currentKm = int.tryParse(_kmCtrl.text) ?? 0;

      // 1. Mark intervention as finished and update vehicle mileage
      await InterventionService.completeIntervention(
        widget.intervention, 
        finalPrice: finalPrice,
        newMileage: currentKm,
      );

      // 2. Add maintenance entries to update health (wear reset to 0)
      for (var update in _updates.where((u) => u.isSelected)) {
        await CarnetService.updateEntry(CarnetEntretien(
          id: '',
          dernierKilometrageChangement: currentKm,
          dateChangement: DateTime.now(),
          niveauUsure: 0.0,
          vehicleId: widget.intervention.vehiculeId,
          composantId: update.composantId,
          nomComposantCustom: update.label,
          categorie: update.category,
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention terminée et véhicule mis à jour'), backgroundColor: Colors.green)
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
      body: _loadingComposants 
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(),
                    const SizedBox(height: 32),
                    _buildKmAndPriceSection(),
                    const SizedBox(height: 32),
                    _buildMaintenanceSection(),
                    const SizedBox(height: 40),
                    _buildSubmitButton(),
                  ],
                ),
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
              Text(widget.intervention.vehiculeNom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 8),
          Text('Type: ${widget.intervention.typeLabel}', style: const TextStyle(color: Color(0xFF64748B))),
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
          validator: (v) => (v == null || v.isEmpty) ? 'Kilométrage requis' : null,
        ),
        const SizedBox(height: 20),
        const Text('Prestation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 16),
        TextFormField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('Prix final de l\'intervention', Icons.monetization_on_rounded, 'DT'),
          validator: (v) => (v == null || v.isEmpty) ? 'Prix requis' : null,
        ),
      ],
    );
  }

  Widget _buildMaintenanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pièces remplacées / Entretien', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const Text('Cochez les éléments que vous avez mis à neuf.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _updates.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final u = _updates[index];
              return CheckboxListTile(
                title: Text(u.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(u.category, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                value: u.isSelected,
                onChanged: (val) => setState(() => u.isSelected = val ?? false),
                activeColor: const Color(0xFF1976D2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              );
            },
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
