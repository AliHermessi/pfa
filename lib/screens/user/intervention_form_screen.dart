import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/intervention.dart';
import '../../models/vehicle.dart';
import '../../models/mecanicien.dart';
import '../../services/intervention_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/planning_service.dart';

class InterventionFormScreen extends StatefulWidget {
  final Intervention? intervention;
  final Mecanicien? initialMecanicien;

  const InterventionFormScreen({super.key, this.intervention, this.initialMecanicien});

  @override
  State<InterventionFormScreen> createState() => _InterventionFormScreenState();
}

class _InterventionFormScreenState extends State<InterventionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  Vehicle? _selectedVehicle;
  Mecanicien? _selectedMecanicien;
  DateTime? _selectedDate;
  int? _selectedHeure;
  List<int> _occupes = [];
  bool _isLoadingSlots = false;
  bool _isLoading = false;

  final TextEditingController _kmController = TextEditingController();
  List<InterventionTask> _tasks = [];
  
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.intervention != null;

  @override
  void initState() {
    super.initState();
    _selectedMecanicien = widget.initialMecanicien;
    
    final i = widget.intervention;
    if (i != null) {
      _tasks = List.from(i.tasks);
      _selectedDate = i.date;
      _selectedHeure = i.date.hour;
      _kmController.text = i.kilometrageCompteur?.toString() ?? '';
      if (_selectedMecanicien != null && _selectedDate != null) {
        _fetchSlots(_selectedDate!);
      }
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages(String interventionId) async {
    List<String> urls = [];
    final storageRef = FirebaseStorage.instance.ref().child('interventions/$interventionId');

    for (var image in _selectedImages) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final fileRef = storageRef.child(fileName);
      await fileRef.putFile(File(image.path));
      final url = await fileRef.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      selectableDayPredicate: (DateTime day) {
        if (_selectedMecanicien == null) return true;
        return _selectedMecanicien!.joursOuverture.contains(day.weekday);
      },
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
      // Ignore
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  void _showTaskDialog({InterventionTask? task, int? index}) {
    InterventionType selectedType = task?.type ?? InterventionType.piece;
    final nameCtrl = TextEditingController(text: task?.name ?? '');
    final descCtrl = TextEditingController(text: task?.description ?? '');
    final taskFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(task == null ? 'Ajouter une demande' : 'Modifier la demande'),
          content: SingleChildScrollView(
            child: Form(
              key: taskFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<InterventionType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: InterventionType.piece, child: Text('Pièce')),
                      DropdownMenuItem(value: InterventionType.fluide, child: Text('Fluide')),
                      DropdownMenuItem(value: InterventionType.controle, child: Text('Contrôle')),
                      DropdownMenuItem(value: InterventionType.autre, child: Text('Autre')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  if (selectedType == InterventionType.piece || selectedType == InterventionType.fluide)
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: selectedType == InterventionType.piece ? 'Nom de la pièce' : 'Nom du fluide',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire' : null,
                    ),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    validator: (v) {
                      if (selectedType == InterventionType.autre) {
                        if (v == null || v.trim().length < 15) {
                          return 'Minimum 15 caractères requis';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (taskFormKey.currentState!.validate()) {
                  final newTask = InterventionTask(
                    type: selectedType,
                    name: (selectedType == InterventionType.piece || selectedType == InterventionType.fluide) ? nameCtrl.text.trim() : null,
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  );
                  setState(() {
                    if (index != null) {
                      _tasks[index] = newTask;
                    } else {
                      _tasks.add(newTask);
                    }
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    if (_selectedVehicle == null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un véhicule')));
      return;
    }
    if (_tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter au moins une demande')));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez choisir une date')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final DateTime finalDate = _selectedHeure != null
          ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedHeure!)
          : _selectedDate!;

      final interventionId = widget.intervention?.id ?? FirebaseDatabase.instance.ref('interventions/$currentUserId').push().key ?? '';

      List<String>? imageUrls;
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages(interventionId);
      } else if (_isEditing) {
        imageUrls = widget.intervention!.imageUrls;
      }

      final intervention = Intervention(
        id: interventionId,
        date: finalDate,
        heure: _selectedHeure != null ? '${_selectedHeure.toString().padLeft(2, '0')}:00' : '${finalDate.hour.toString().padLeft(2, '0')}:${finalDate.minute.toString().padLeft(2, '0')}',
        statutLabelDiagram: _isEditing ? widget.intervention!.statut.name : 'En attente',
        vehiculeId: _selectedVehicle?.id ?? widget.intervention?.vehiculeId ?? '',
        vehiculeNom: _selectedVehicle?.nomComplet ?? widget.intervention?.vehiculeNom ?? '',
        userId: currentUserId,
        tasks: _tasks,
        prixEstime: 0, 
        statut: _isEditing ? widget.intervention!.statut : InterventionStatut.enAttente,
        mecanicienNom: _selectedMecanicien?.nom ?? widget.intervention?.mecanicienNom,
        mecanicienId: _selectedMecanicien?.id ?? widget.intervention?.mecanicienId,
        kilometrageCompteur: int.tryParse(_kmController.text) ?? _selectedVehicle?.kilometrageActuel,
        imageUrls: imageUrls,
      );

      await InterventionService.addIntervention(intervention);
      if (!_isEditing && _selectedMecanicien != null && _selectedHeure != null) {
        await PlanningService.bloquerCreneau(_selectedMecanicien!.id, finalDate);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée !'), backgroundColor: Color(0xFF2E7D32)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
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
        elevation: 0,
        title: Text(_isEditing ? 'Modifier la demande' : 'Prendre Rendez-vous', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Véhicule & Mécanicien'),
              _buildCard(
                child: Column(
                  children: [
                    StreamBuilder<List<Vehicle>>(
                      stream: VehicleService.vehiclesStream(),
                      builder: (context, snapshot) {
                        final vehicles = snapshot.data ?? [];
                        Vehicle? safeValue;
                        if (_selectedVehicle != null && vehicles.any((v) => v.id == _selectedVehicle!.id)) {
                          safeValue = vehicles.firstWhere((v) => v.id == _selectedVehicle!.id);
                        }

                        return DropdownButtonFormField<Vehicle>(
                          value: safeValue,
                          hint: const Text('Sélectionner un véhicule'),
                          items: vehicles.map((v) => DropdownMenuItem(value: v, child: Text('${v.nomComplet} (${v.immatriculation})'))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedVehicle = v;
                              if (v != null && !_isEditing) {
                                _kmController.text = v.kilometrageActuel.toString();
                              }
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _kmController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kilométrage actuel au compteur',
                        prefixIcon: Icon(Icons.speed),
                        suffixText: 'km',
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Veuillez confirmer le kilométrage' : null,
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<DatabaseEvent>(
                      stream: FirebaseDatabase.instance.ref('mecaniciens').onValue,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return const SizedBox();
                        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                        final list = data.entries.map((e) => Mecanicien.fromMap(e.key as String, e.value as Map)).toList();
                        
                        Mecanicien? safeMecValue;
                        if (_selectedMecanicien != null && list.any((m) => m.id == _selectedMecanicien!.id)) {
                          safeMecValue = list.firstWhere((m) => m.id == _selectedMecanicien!.id);
                        }

                        return DropdownButtonFormField<Mecanicien>(
                          value: safeMecValue,
                          hint: const Text('Choisir un mécanicien (Optionnel)'),
                          items: list.map((m) => DropdownMenuItem(value: m, child: Text('${m.nom} (${m.specialite})'))).toList(),
                          onChanged: (m) {
                            setState(() {
                              _selectedMecanicien = m;
                              _selectedDate = null;
                              _selectedHeure = null;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Détails de l\'intervention'),
              _buildCard(
                child: Column(
                  children: [
                    ..._tasks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final t = entry.value;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: t.description != null ? Text(t.description!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _tasks.removeAt(index))),
                        onTap: () => _showTaskDialog(task: t, index: index),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showTaskDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une demande'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Photos (Optionnel)'),
              _buildCard(
                child: Column(
                  children: [
                    if (_selectedImages.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(File(_selectedImages[index].path), width: 100, height: 100, fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Ajouter des photos'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Planification'),
              _buildCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date souhaitée'),
                      trailing: Text(_selectedDate == null ? 'Choisir' : DateFormat('dd/MM/yyyy').format(_selectedDate!)),
                      onTap: _pickDate,
                    ),
                    if (_selectedDate != null && _selectedMecanicien != null) _buildTimeSlots(),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SOUMETTRE LA DEMANDE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: child,
    );
  }

  Widget _buildTimeSlots() {
    if (_isLoadingSlots) return const Center(child: CircularProgressIndicator());
    final slots = List.generate(_selectedMecanicien!.heuresFin - _selectedMecanicien!.heuresDebut + 1, (i) => _selectedMecanicien!.heuresDebut + i);
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Heures disponibles :', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: slots.map((h) {
              final isOccupied = _occupes.contains(h);
              final isSelected = _selectedHeure == h;
              return ChoiceChip(
                label: Text('${h.toString().padLeft(2, '0')}:00'),
                selected: isSelected,
                onSelected: isOccupied ? null : (val) => setState(() => _selectedHeure = val ? h : null),
                disabledColor: Colors.grey.shade200,
                selectedColor: const Color(0xFF1976D2),
                labelStyle: TextStyle(color: isSelected ? Colors.white : (isOccupied ? Colors.grey : Colors.black)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
