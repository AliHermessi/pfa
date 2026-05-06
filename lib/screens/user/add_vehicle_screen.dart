import 'package:flutter/material.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';

class AddVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle; // null = ajout, non-null = modification

  const AddVehicleScreen({super.key, this.vehicle});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _marqueCtrl;
  late final TextEditingController _modeleCtrl;
  late final TextEditingController _immaCtrl;
  late final TextEditingController _kmCtrl;
  late final TextEditingController _kmVidangeCtrl;
  DateTime? _prochainControle;
  bool _isLoading = false;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _marqueCtrl = TextEditingController(text: v?.marque ?? '');
    _modeleCtrl = TextEditingController(text: v?.modele ?? '');
    _immaCtrl = TextEditingController(text: v?.immatriculation ?? '');
    _kmCtrl = TextEditingController(text: v?.kilometrage.toString() ?? '');
    _kmVidangeCtrl = TextEditingController(
        text: v?.kilometrageProchVidange.toString() ?? '');
    _prochainControle = v?.prochainControle;
  }

  @override
  void dispose() {
    _marqueCtrl.dispose();
    _modeleCtrl.dispose();
    _immaCtrl.dispose();
    _kmCtrl.dispose();
    _kmVidangeCtrl.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _prochainControle ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1976D2)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _prochainControle = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_prochainControle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Veuillez sélectionner la date du contrôle technique')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vehicle = Vehicle(
        // Si modification : on garde l'ancien id, sinon Firebase génère un id automatiquement
        id: widget.vehicle?.id ?? '',
        marque: _marqueCtrl.text.trim(),
        modele: _modeleCtrl.text.trim(),
        immatriculation: _immaCtrl.text.trim().toUpperCase(),
        kilometrage: int.parse(_kmCtrl.text.trim()),
        kilometrageProchVidange: int.parse(_kmVidangeCtrl.text.trim()),
        prochainControle: _prochainControle!,
        sante: 0.8,
      );

      if (_isEditing) {
        await VehicleService.updateVehicle(vehicle);
      } else {
        await VehicleService.addVehicle(vehicle);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Véhicule modifié avec succès'
                : 'Véhicule ajouté avec succès'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Modifier le véhicule' : 'Ajouter un véhicule',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCard(children: [
                _buildField('Marque', 'Ex: Renault', _marqueCtrl),
                const SizedBox(height: 14),
                _buildField('Modèle', 'Ex: Clio IV', _modeleCtrl),
                const SizedBox(height: 14),
                _buildField('Immatriculation', 'Ex: TUN 142 B', _immaCtrl),
              ]),
              const SizedBox(height: 14),
              _buildCard(children: [
                _buildField(
                  'Kilométrage actuel',
                  'Ex: 87450',
                  _kmCtrl,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _buildField(
                  'Kilométrage prochaine vidange',
                  'Ex: 90000',
                  _kmVidangeCtrl,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Date prochain contrôle technique',
                        hintText: _prochainControle == null
                            ? 'Sélectionner une date'
                            : '${_prochainControle!.day}/${_prochainControle!.month}/${_prochainControle!.year}',
                        suffixIcon: const Icon(Icons.calendar_today,
                            color: Color(0xFF1976D2)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      controller: TextEditingController(
                        text: _prochainControle == null
                            ? ''
                            : '${_prochainControle!.day}/${_prochainControle!.month}/${_prochainControle!.year}',
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isEditing
                              ? 'Enregistrer les modifications'
                              : 'Ajouter le véhicule',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildField(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Ce champ est requis' : null,
        ),
      ],
    );
  }
}
