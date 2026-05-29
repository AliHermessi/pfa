import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/utilisateur.dart';
import '../../models/client.dart';
import '../../models/mecanicien.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;
  Utilisateur? _user;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nomCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _adresseCtrl;
  late TextEditingController _nomGarageCtrl;
  late TextEditingController _adresseGarageCtrl;

  // For Mechanic location
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _adresseCtrl = TextEditingController();
    _nomGarageCtrl = TextEditingController();
    _adresseGarageCtrl = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _user = user;
        _nomCtrl.text = user.nom;
        _phoneCtrl.text = user.telephone;
        _emailCtrl.text = user.email;
        _imageFile = null;
        if (user is Client) {
          _adresseCtrl.text = user.adresse;
        } else if (user is Mecanicien) {
          _nomGarageCtrl.text = user.nomGarage;
          _adresseGarageCtrl.text = user.adresseGarage;
          if (user.latitude != null && user.longitude != null) {
            _selectedLocation = LatLng(user.latitude!, user.longitude!);
          }
        }
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _adresseCtrl.dispose();
    _nomGarageCtrl.dispose();
    _adresseGarageCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;
    
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection de l\'image : $e')),
        );
      }
    }
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez activer le GPS')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      Position position = await Geolocator.getCurrentPosition();
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() => _selectedLocation = newPos);
      _mapController.move(newPos, 15);
      _reverseGeocode(newPos);
    } catch (e) {
      debugPrint("Error GPS: $e");
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'VroomLogApp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'];
        if (address != null && mounted) {
          setState(() {
            _adresseGarageCtrl.text = address;
          });
        }
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String? uploadedUrl;
      if (_imageFile != null) {
        uploadedUrl = await AuthService.uploadProfilePhoto(_imageFile!);
      }

      await AuthService.updateProfile(
        nom: _nomCtrl.text.trim(),
        telephone: _phoneCtrl.text.trim(),
        photoUrl: uploadedUrl ?? _user?.photoUrl,
        adresse: _user is Client ? _adresseCtrl.text.trim() : null,
        nomGarage: _user is Mecanicien ? _nomGarageCtrl.text.trim() : null,
        adresseGarage: _user is Mecanicien ? _adresseGarageCtrl.text.trim() : null,
        latitude: _user is Mecanicien ? _selectedLocation?.latitude : null,
        longitude: _user is Mecanicien ? _selectedLocation?.longitude : null,
      );
      
      if (mounted) {
        setState(() {
          _isEditing = false;
          _imageFile = null;
        });
        await _loadUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
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
        elevation: 0,
        title: const Text('Mon Profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading && _user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Informations Personnelles'),
                          const SizedBox(height: 15),
                          _buildTextField(
                            label: 'Nom Complet',
                            controller: _nomCtrl,
                            icon: Icons.person_outline,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(
                            label: 'E-mail',
                            controller: _emailCtrl,
                            icon: Icons.email_outlined,
                            enabled: false,
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(
                            label: 'Téléphone',
                            controller: _phoneCtrl,
                            icon: Icons.phone_outlined,
                            enabled: _isEditing,
                            keyboardType: TextInputType.phone,
                          ),
                          if (_user is Client) ...[
                            const SizedBox(height: 15),
                            _buildTextField(
                              label: 'Adresse',
                              controller: _adresseCtrl,
                              icon: Icons.location_on_outlined,
                              enabled: _isEditing,
                            ),
                          ],
                          if (_user is Mecanicien) ...[
                            const SizedBox(height: 25),
                            _buildSectionTitle('Informations Professionnelles'),
                            const SizedBox(height: 15),
                            _buildTextField(
                              label: 'Nom du Garage',
                              controller: _nomGarageCtrl,
                              icon: Icons.store_outlined,
                              enabled: _isEditing,
                            ),
                            const SizedBox(height: 15),
                            _buildTextField(
                              label: 'Adresse du Garage',
                              controller: _adresseGarageCtrl,
                              icon: Icons.map_outlined,
                              enabled: _isEditing,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 15),
                            if (_isEditing) _buildMapPicker(),
                          ],
                          const SizedBox(height: 30),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMapPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Localisation sur la carte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1976D2))),
            IconButton(
              icon: _isLoadingGps ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location, color: Color(0xFF1976D2)),
              onPressed: _determinePosition,
            ),
          ],
        ),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation ?? const LatLng(36.8, 10.1),
                initialZoom: 13,
                onTap: (tapPosition, point) {
                  setState(() => _selectedLocation = point);
                  _reverseGeocode(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.vroomlog.app',
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Appuyez sur la carte pour déplacer le garage.', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildHeader() {
    ImageProvider? backgroundImage;
    if (_imageFile != null) {
      backgroundImage = FileImage(_imageFile!);
    } else if (_user?.photoUrl != null && _user!.photoUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(_user!.photoUrl!);
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1976D2),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 40, top: 10),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isEditing ? _pickImage : null,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: backgroundImage,
                    child: backgroundImage == null
                        ? const Icon(Icons.person, size: 70, color: Color(0xFF1976D2))
                        : null,
                  ),
                ),
                if (_isEditing)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _user?.nom ?? 'Utilisateur',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            _user?.role == 'mecanicien' ? 'Mécanicien Professionnel' : 'Propriétaire de véhicule',
            style: TextStyle(color: Colors.blue.shade100, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ce champ est requis' : null,
    );
  }

  Widget _buildActionButtons() {
    if (!_isEditing) {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.edit, color: Colors.white),
          label: const Text('Modifier le profil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 55,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _imageFile = null;
                });
                _loadUserData();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}
