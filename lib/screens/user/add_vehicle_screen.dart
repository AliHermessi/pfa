import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../models/composant.dart';
import '../../models/carnet_entretien.dart';
import '../../services/vehicle_service.dart';
import '../../services/composant_service.dart';
import '../../services/carnet_service.dart';

class AddVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle; 

  const AddVehicleScreen({super.key, this.vehicle});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _MaintenanceEntry {
  String label;
  String? composantId;
  int? km;
  DateTime? date;
  bool isCustom;
  String category; 
  bool isNeverReplaced;

  _MaintenanceEntry({
    required this.label,
    this.composantId,
    this.km,
    this.date,
    this.isCustom = false,
    this.category = 'PIECE',
    this.isNeverReplaced = false,
  });
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  int _currentStep = 0;
  final _formKeyStep1 = GlobalKey<FormState>();
  
  late final TextEditingController _marqueCtrl;
  late final TextEditingController _modeleCtrl;
  late final TextEditingController _immaCtrl;
  late final TextEditingController _kmCtrl;
  late final TextEditingController _kmVidangeCtrl;
  DateTime? _dateVidange; 
  bool _vidangeNeverDone = false;
  DateTime? _prochainControle;

  List<_MaintenanceEntry> _maintenanceEntries = [];
  bool _loadingComposants = false;
  bool _isLoading = false;

  // Image handling
  final List<XFile> _selectedImages = [];
  List<String> _existingImageUrls = [];
  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _marqueCtrl = TextEditingController(text: v?.marque ?? '');
    _modeleCtrl = TextEditingController(text: v?.modele ?? '');
    _immaCtrl = TextEditingController(text: v?.immatriculation ?? '');
    _kmCtrl = TextEditingController(text: v?.kilometrageActuel.toString() ?? '');
    _kmVidangeCtrl = TextEditingController();
    _prochainControle = (v != null && v.prochainControle.year > 2000) ? v.prochainControle : null;
    _existingImageUrls = v?.imageUrls != null ? List<String>.from(v!.imageUrls) : [];
    _initializeMaintenanceEntries();
  }

  Future<void> _initializeMaintenanceEntries() async {
    setState(() => _loadingComposants = true);
    try {
      final allComps = await ComposantService.allComposantsStream().first;
      
      List<CarnetEntretien> existingEntries = [];
      if (_isEditing) {
        existingEntries = await CarnetService.vehicleCarnetStream(widget.vehicle!.id).first;
      }

      setState(() {
        // Standard components
        _maintenanceEntries = allComps
          .where((c) => c.categorie != 'CONTROLE' && c.id != 'oil_change')
          .map((c) {
            final existing = existingEntries.cast<CarnetEntretien?>().firstWhere(
              (e) => e?.composantId == c.id, 
              orElse: () => null
            );

            return _MaintenanceEntry(
              label: c.nom,
              composantId: c.id,
              category: c.categorie,
              km: existing?.dernierKilometrageChangement,
              date: existing?.dateChangement,
              isNeverReplaced: existing?.dateChangement.year == 2000,
            );
          }).toList();
        
        // Custom entries
        for (var e in existingEntries) {
          if (e.composantId != 'oil_change' && !allComps.any((c) => c.id == e.composantId)) {
            _maintenanceEntries.add(_MaintenanceEntry(
              label: e.nomComposantCustom ?? 'Entretien',
              composantId: e.composantId,
              category: e.categorie,
              km: e.dernierKilometrageChangement,
              date: e.dateChangement,
              isCustom: true,
              isNeverReplaced: e.dateChangement.year == 2000,
            ));
          }
        }
        
        // Oil change
        final oilEntry = existingEntries.cast<CarnetEntretien?>().firstWhere(
          (e) => e?.composantId == 'oil_change',
          orElse: () => null
        );
        if (oilEntry != null) {
          _vidangeNeverDone = oilEntry.dateChangement.year == 2000;
          if (!_vidangeNeverDone) {
            _kmVidangeCtrl.text = oilEntry.dernierKilometrageChangement.toString();
            _dateVidange = oilEntry.dateChangement;
          }
        }

        _loadingComposants = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingComposants = false);
    }
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

  Future<void> _pickImage() async {
    if (_selectedImages.length + _existingImageUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 photos autorisées')));
      return;
    }
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _selectedImages.add(image));
    }
  }

  void _removeNewImage(int index) => setState(() => _selectedImages.removeAt(index));
  void _removeExistingImage(int index) => setState(() => _existingImageUrls.removeAt(index));

  Future<List<String>> _uploadImages(String vehicleId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _existingImageUrls;

    // Parallel upload
    final newUrls = await Future.wait(_selectedImages.map((xf) async {
      final ref = FirebaseStorage.instance
          .ref()
          .child('vehicles/$uid/$vehicleId/${DateTime.now().millisecondsSinceEpoch}_${xf.name}');
      await ref.putFile(File(xf.path));
      return await ref.getDownloadURL();
    }));

    return [..._existingImageUrls, ...newUrls];
  }

  void _showEntryDialog({_MaintenanceEntry? existingEntry, bool isNew = false}) {
    final entry = existingEntry ?? _MaintenanceEntry(label: '', isCustom: true);
    final kmCtrl = TextEditingController(text: entry.isNeverReplaced ? '0' : (entry.km?.toString() ?? ''));
    final nameCtrl = TextEditingController(text: entry.label);
    DateTime? selectedDate = entry.isNeverReplaced ? DateTime(2000) : entry.date;
    String selectedCategory = entry.category;
    bool neverReplaced = entry.isNeverReplaced;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Nouvel entretien' : 'Maintenance : ${entry.label}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.isCustom)
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Désignation (ex: Eau radiateur)'),
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text("Jamais remplacé", style: TextStyle(fontSize: 14)),
                  value: neverReplaced,
                  onChanged: (val) {
                    setDialogState(() {
                      neverReplaced = val ?? false;
                      if (neverReplaced) {
                        kmCtrl.text = '0';
                        selectedDate = DateTime(2000);
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                if (!neverReplaced) ...[
                  TextField(
                    controller: kmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kilométrage effectué', suffixText: 'km'),
                  ),
                  const SizedBox(height: 16),
                  if (entry.isCustom)
                    DropdownButtonFormField<String>(
                      value: selectedCategory == 'CONTROLE' ? 'PIECE' : selectedCategory,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      items: const [
                        DropdownMenuItem(value: 'PIECE', child: Text('Pièce')),
                        DropdownMenuItem(value: 'FLUIDE', child: Text('Fluide')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedCategory = v!),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(selectedDate == null ? 'Choisir Date' : DateFormat('dd/MM/yy').format(selectedDate!)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (!neverReplaced && (kmCtrl.text.isEmpty || selectedDate == null || (entry.isCustom && nameCtrl.text.isEmpty))) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir le kilométrage et la date')));
                  return;
                }
                setState(() {
                  if (isNew) {
                    _maintenanceEntries.add(_MaintenanceEntry(
                      label: nameCtrl.text.trim(),
                      km: neverReplaced ? 0 : int.tryParse(kmCtrl.text),
                      date: neverReplaced ? DateTime(2000) : selectedDate,
                      isCustom: true,
                      category: selectedCategory,
                      isNeverReplaced: neverReplaced,
                    ));
                  } else {
                    entry.km = neverReplaced ? 0 : int.tryParse(kmCtrl.text);
                    entry.date = neverReplaced ? DateTime(2000) : selectedDate;
                    entry.isNeverReplaced = neverReplaced;
                    if (entry.isCustom) {
                      entry.label = nameCtrl.text.trim();
                      entry.category = selectedCategory;
                    }
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKeyStep1.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final kmActuel = int.parse(_kmCtrl.text.trim());

      final vidangeKmStr = _kmVidangeCtrl.text.trim();
      final vidangeKm = _vidangeNeverDone ? 0 : (vidangeKmStr.isNotEmpty ? int.tryParse(vidangeKmStr) : null);
      
      int nextVidangeKm;
      if (vidangeKm != null) {
        nextVidangeKm = vidangeKm + 8000;
      } else {
        nextVidangeKm = _isEditing ? widget.vehicle!.kilometrageProchVidange : kmActuel + 100000;
      }

      String vehicleId = _isEditing ? widget.vehicle!.id : FirebaseDatabase.instance.ref('vehicles/$uid').push().key!;

      final List<String> imageUrls = await _uploadImages(vehicleId);

      final vehicle = Vehicle(
        id: vehicleId,
        marque: _marqueCtrl.text.trim(),
        modele: _modeleCtrl.text.trim(),
        immatriculation: _immaCtrl.text.trim().toUpperCase(),
        kilometrageActuel: kmActuel,
        kilometrageProchVidange: nextVidangeKm,
        prochainControle: _prochainControle ?? DateTime.fromMillisecondsSinceEpoch(0),
        sante: 0.0, 
        clientId: uid,
        dernierMiseAJourKm: DateTime.now(),
        rappelKmJours: widget.vehicle?.rappelKmJours ?? 7,
        mileageHistory: widget.vehicle?.mileageHistory ?? [],
        imageUrls: imageUrls,
      );

      if (_isEditing) {
        await VehicleService.updateVehicle(vehicle);
      } else {
        await VehicleService.addVehicle(vehicle);
      }

      if (vidangeKm != null || _vidangeNeverDone) {
        await CarnetService.updateEntry(CarnetEntretien(
          id: '', 
          dernierKilometrageChangement: vidangeKm ?? 0,
          dateChangement: _vidangeNeverDone ? DateTime(2000) : (_dateVidange ?? DateTime.now()),
          niveauUsure: 0.0,
          vehicleId: vehicleId,
          composantId: 'oil_change',
          nomComposantCustom: 'Vidange Huile Moteur',
          categorie: 'FLUIDE',
        ));
      }

      for (var entry in _maintenanceEntries) {
        if (entry.isNeverReplaced || (entry.km != null && entry.date != null)) {
          final carnetEntry = CarnetEntretien(
            id: '', 
            dernierKilometrageChangement: entry.km ?? 0,
            dateChangement: entry.date ?? DateTime(2000),
            niveauUsure: 0.0, 
            vehicleId: vehicleId,
            composantId: entry.composantId ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
            nomComposantCustom: entry.label,
            categorie: entry.category,
          );
          await CarnetService.updateEntry(carnetEntry);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Véhicule enregistré avec succès'), backgroundColor: Color(0xFF2E7D32)));
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
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(_isEditing ? 'Modifier le véhicule' : 'Nouveau véhicule', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        onStepContinue: () {
          if (_currentStep == 0) {
            if (_formKeyStep1.currentState!.validate()) {
              setState(() => _currentStep = 1);
            }
          } else {
            _submit();
          }
        },
        onStepCancel: () => _currentStep > 0 ? setState(() => _currentStep = 0) : Navigator.pop(context),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_currentStep == 0 ? 'Suivant' : 'Terminer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: details.onStepCancel, child: Text(_currentStep == 0 ? 'Annuler' : 'Retour', style: const TextStyle(color: Colors.grey))),
            ],
          ),
        ),
        steps: [
          Step(
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            title: const Text('Véhicule'),
            content: Form(
              key: _formKeyStep1,
              child: Column(
                children: [
                  _buildField('Marque *', 'Ex: Renault', _marqueCtrl),
                  const SizedBox(height: 14),
                  _buildField('Modèle *', 'Ex: Clio IV', _modeleCtrl),
                  const SizedBox(height: 14),
                  _buildField('Immatriculation', 'Ex: TUN 142 B', _immaCtrl, required: false),
                  const SizedBox(height: 14),
                  _buildField('Kilométrage actuel *', 'Ex: 87000', _kmCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  _buildPhotoSection(),
                  const SizedBox(height: 16),
                  _buildVidangeSection(),
                ],
              ),
            ),
          ),
          Step(
            isActive: _currentStep >= 1,
            title: const Text('Historique'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Maintenance des composants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  'Optionnel : Cliquez sur un élément pour renseigner sa dernière maintenance.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (_loadingComposants)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  ..._maintenanceEntries.map((entry) => _buildMaintenanceCard(entry)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showEntryDialog(isNew: true),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un entretien spécifique'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1976D2), side: const BorderSide(color: Color(0xFF1976D2))),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos du véhicule (Max 3)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._existingImageUrls.asMap().entries.map((e) => _buildThumbnail(url: e.value, onRemove: () => _removeExistingImage(e.key))),
              ..._selectedImages.asMap().entries.map((e) => _buildThumbnail(file: File(e.value.path), onRemove: () => _removeNewImage(e.key))),
              if (_existingImageUrls.length + _selectedImages.length < 3)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: const Icon(Icons.add_a_photo, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail({String? url, File? file, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 80, height: 80,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url != null 
              ? Image.network(url, fit: BoxFit.cover, width: 80, height: 80)
              : Image.file(file!, fit: BoxFit.cover, width: 80, height: 80),
          ),
          Positioned(
            right: 0, top: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVidangeSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dernière Vidange Huile (Optionnel)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
          const SizedBox(height: 10),
          CheckboxListTile(
            title: const Text("Jamais effectuée", style: TextStyle(fontSize: 13)),
            value: _vidangeNeverDone,
            onChanged: (v) => setState(() => _vidangeNeverDone = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          if (!_vidangeNeverDone)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _kmVidangeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Km', suffixText: 'km', border: OutlineInputBorder(), isDense: true, fillColor: Colors.white, filled: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: _dateVidange ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                      if (picked != null) setState(() => _dateVidange = picked);
                    },
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                    child: Text(_dateVidange == null ? 'Date' : DateFormat('dd/MM/yy').format(_dateVidange!)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(_MaintenanceEntry entry) {
    bool isFilled = entry.isNeverReplaced || (entry.km != null && entry.date != null);
    String statusText = entry.isNeverReplaced 
        ? 'Jamais remplacé' 
        : (isFilled ? '${entry.km} km le ${DateFormat('dd/MM/yy').format(entry.date!)}' : 'Non renseigné');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: isFilled ? const Color(0xFF1976D2) : Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: () => _showEntryDialog(existingEntry: entry),
        leading: Icon(isFilled ? Icons.check_circle : Icons.circle_outlined, color: isFilled ? Colors.green : Colors.grey),
        title: Text(entry.label, style: TextStyle(fontWeight: FontWeight.bold, color: isFilled ? const Color(0xFF1976D2) : Colors.black87)),
        subtitle: Text(statusText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.edit_outlined, size: 18),
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, bool required = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null : null,
        ),
      ],
    );
  }
}
