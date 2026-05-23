import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/intervention.dart';
import '../../models/vehicle.dart';
import '../../models/mecanicien.dart';
import '../../services/intervention_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/planning_service.dart';

class InterventionFormScreen extends StatefulWidget {
  final Intervention? intervention; // null = ajout, non-null = modification

  const InterventionFormScreen({super.key, this.intervention});

  @override
  State<InterventionFormScreen> createState() => _InterventionFormScreenState();
}

class _InterventionFormScreenState extends State<InterventionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _prixCtrl;
  late final TextEditingController _piecesCtrl;

  Vehicle? _selectedVehicle;
  Mecanicien? _selectedMecanicien;
  late InterventionType _selectedType;
  DateTime? _selectedDate;
  int? _selectedHeure;
  List<int> _occupes = [];
  bool _isLoadingSlots = false;
  late InterventionStatut _selectedStatut;
  bool _isLoading = false;

  bool get _isEditing => widget.intervention != null;

  static const List<_TypeOption> _types = [
    _TypeOption(InterventionType.vidange, 'Vidange', Icons.oil_barrel_outlined),
    _TypeOption(InterventionType.pneus, 'Pneus', Icons.tire_repair_outlined),
    _TypeOption(InterventionType.batterie, 'Batterie',
        Icons.battery_charging_full_outlined),
    _TypeOption(InterventionType.freins, 'Freins', Icons.disc_full_outlined),
    _TypeOption(InterventionType.filtreAir, 'Filtre Air', Icons.air_outlined),
    _TypeOption(InterventionType.autre, 'Autre', Icons.build_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.intervention;
    _descriptionCtrl = TextEditingController(text: i?.description ?? '');
    _prixCtrl = TextEditingController(
        text: i != null ? i.prixEstime.toStringAsFixed(0) : '');
    _piecesCtrl =
        TextEditingController(text: i != null ? i.pieces.join(', ') : '');
    _selectedType = i?.type ?? InterventionType.vidange;
    _selectedDate = i?.date;
    if (i?.date != null && i?.mecanicienId != null) {
      _selectedHeure = i!.date.hour;
    }
    _selectedStatut = i?.statut ?? InterventionStatut.enAttente;
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _prixCtrl.dispose();
    _piecesCtrl.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(), // On ne peut pas planifier dans le passé
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1976D2)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedHeure = null;
      });
      if (_selectedMecanicien != null) {
        _fetchSlots(picked);
      }
    }
  }

  Future<void> _fetchSlots(DateTime date) async {
    if (_selectedMecanicien == null) return;
    setState(() => _isLoadingSlots = true);
    try {
      final occupes = await PlanningService.getCreneauxOccupes(_selectedMecanicien!.id, date);
      if (mounted) setState(() => _occupes = occupes);
    } catch (e) {
      // Ignorer erreur silencieusement
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _submit() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    if (_selectedVehicle == null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un véhicule')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une date')),
      );
      return;
    }
    if (_selectedMecanicien != null && _selectedHeure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une heure de rendez-vous')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pieces = _piecesCtrl.text
          .trim()
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      final intervention = Intervention(
        id: widget.intervention?.id ?? '',
        vehiculeId:
            _selectedVehicle?.id ?? widget.intervention?.vehiculeId ?? '',
        vehiculeNom:
            _selectedVehicle?.nomComplet ?? widget.intervention?.vehiculeNom ?? '',
        userId: currentUserId,
        type: _selectedType,
        description: _descriptionCtrl.text.trim(),
        pieces: pieces,
        prixEstime: double.tryParse(_prixCtrl.text.trim()) ?? 0,
        date: _selectedHeure != null
            ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedHeure!)
            : _selectedDate!,
        statut: _isEditing ? _selectedStatut : InterventionStatut.enAttente,
        mecanicienNom: _selectedMecanicien?.nom ?? widget.intervention?.mecanicienNom,
        mecanicienId: _selectedMecanicien?.id ?? widget.intervention?.mecanicienId,
      );

      if (_isEditing) {
        await InterventionService.addIntervention(intervention);
      } else {
        await InterventionService.addIntervention(intervention);
        if (_selectedMecanicien != null && _selectedHeure != null) {
          await PlanningService.bloquerCreneau(_selectedMecanicien!.id, intervention.date);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Intervention modifiée avec succès !'
                : 'Demande envoyée au mécanicien !'),
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
          _isEditing ? 'Modifier Intervention' : 'Nouvelle Intervention',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Véhicule ──────────────────────────────────────────────
              if (!_isEditing) ...[
                _buildCard(
                  title: 'Véhicule concerné',
                  child: StreamBuilder<List<Vehicle>>(
                    stream: VehicleService.vehiclesStream(),
                    builder: (context, snapshot) {
                      final vehicles = snapshot.data ?? [];
                      return DropdownButtonFormField<Vehicle>(
                        value: _selectedVehicle,
                        hint: const Text('Sélectionner un véhicule'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: vehicles
                            .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                      '${v.nomComplet} — ${v.immatriculation}'),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedVehicle = v),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Mécanicien ─────────────────────────────────────────────
              if (!_isEditing) ...[
                _buildCard(
                  title: 'Choisir un mécanicien',
                  child: StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance.ref('mecaniciens').onValue,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                        return const Text('Aucun mécanicien disponible');
                      }
                      final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                      final list = data.entries.map((e) => Mecanicien.fromMap(e.key as String, e.value as Map)).toList();

                      return DropdownButtonFormField<Mecanicien>(
                        value: _selectedMecanicien,
                        hint: const Text('Sélectionner un mécanicien'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: list
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('${m.nom} (${m.specialite})'),
                                ))
                            .toList(),
                        onChanged: (m) {
                            setState(() => _selectedMecanicien = m);
                            if (_selectedDate != null && m != null) {
                              _fetchSlots(_selectedDate!);
                            }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Type d'intervention ───────────────────────────────────
              _buildCard(
                title: 'Type d\'intervention',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _types.map((t) {
                    final isSelected = _selectedType == t.type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = t.type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1976D2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1976D2)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.icon,
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // ── Détails ───────────────────────────────────────────────
              _buildCard(
                title: 'Détails',
                child: Column(
                  children: [
                    _buildField(
                      'Pièces utilisées (séparées par virgule)',
                      'Ex: Huile 5W30, Filtre à huile',
                      _piecesCtrl,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            'Prix estimé (DT)',
                            'Ex: 85.00',
                            _prixCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            required: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: AbsorbPointer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Date souhaitée',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    decoration: InputDecoration(
                                      hintText: _selectedDate == null
                                          ? 'JJ/MM/AAAA'
                                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                      suffixIcon: const Icon(
                                          Icons.calendar_today,
                                          size: 18,
                                          color: Color(0xFF1976D2)),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                    ),
                                    controller: TextEditingController(
                                      text: _selectedDate == null
                                          ? ''
                                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedDate != null && _selectedMecanicien != null) ...[
                      const SizedBox(height: 14),
                      _buildTimeSlots(),
                    ],
                    const SizedBox(height: 14),
                    _buildField(
                      'Description / Note',
                      'Décrivez le problème ou la demande...',
                      _descriptionCtrl,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          _isEditing ? Icons.save : Icons.send,
                          color: Colors.white),
                  label: Text(
                    _isLoading
                        ? 'Enregistrement...'
                        : _isEditing
                            ? 'Enregistrer les modifications'
                            : 'Soumettre la demande',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1976D2))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTimeSlots() {
    if (_isLoadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }

    final debut = _selectedMecanicien!.heuresDebut;
    final fin = _selectedMecanicien!.heuresFin;
    final slots = <int>[];
    for (int i = debut; i < fin; i++) {
      slots.add(i);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Heure du rendez-vous', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((heure) {
            final isOccupied = _occupes.contains(heure);
            final isSelected = _selectedHeure == heure;
            
            return GestureDetector(
              onTap: isOccupied ? null : () {
                setState(() => _selectedHeure = heure);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? Colors.grey.shade200
                      : isSelected
                          ? const Color(0xFF1976D2)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOccupied
                        ? Colors.grey.shade300
                        : isSelected
                            ? const Color(0xFF1976D2)
                            : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  '${heure.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    fontSize: 13,
                    color: isOccupied
                        ? Colors.grey.shade400
                        : isSelected
                            ? Colors.white
                            : Colors.grey.shade800,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
          ),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty)
                  ? 'Ce champ est requis'
                  : null
              : null,
        ),
      ],
    );
  }
}

class _TypeOption {
  final InterventionType type;
  final String label;
  final IconData icon;
  const _TypeOption(this.type, this.label, this.icon);
}

