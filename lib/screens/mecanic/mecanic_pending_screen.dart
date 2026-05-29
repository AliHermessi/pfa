import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MecanicPendingScreen extends StatefulWidget {
  const MecanicPendingScreen({super.key});

  @override
  State<MecanicPendingScreen> createState() => _MecanicPendingScreenState();
}

class _MecanicPendingScreenState extends State<MecanicPendingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomGarageController = TextEditingController();
  final _adresseController = TextEditingController();
  String? _specialite;
  
  LatLng? _selectedLocation;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  bool _isLoadingGps = false;
  final MapController _mapController = MapController();

  final List<String> _specialties = [
    'Mécanique générale',
    'Vidange et entretien',
    'Freinage',
    'Suspension et direction',
    'Électricité et diagnostic',
    'Climatisation',
    'Pneumatiques',
    'Carrosserie et peinture',
    'Autre'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final snapshot = await FirebaseDatabase.instance.ref('mecaniciens/$uid').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      setState(() {
        _nomGarageController.text = data['nomGarage'] ?? '';
        _adresseController.text = data['adresseGarage'] ?? '';
        _specialite = data['specialite'];
        if (data['latitude'] != null && data['longitude'] != null) {
          _selectedLocation = LatLng(data['latitude'], data['longitude']);
        }
        
        if (data['statutCompte'] == 'en_revision' || data['isApproved'] == true) {
          _hasSubmitted = true;
        }
      });
      
      // Si on n'a pas encore de location, on tente le GPS auto
      if (_selectedLocation == null && !_hasSubmitted) {
        _determinePosition();
      }
    }
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez activer le GPS de votre téléphone')),
        );
        setState(() => _isLoadingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingGps = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingGps = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      final newPos = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = newPos;
      });
      
      _mapController.move(newPos, 15);
      _reverseGeocode(newPos);
      
    } catch (e) {
      debugPrint("Error getting location: $e");
    } finally {
      setState(() => _isLoadingGps = false);
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'VroomLogApp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'];
        if (address != null) {
          setState(() {
            _adresseController.text = address;
          });
        }
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs et choisir une localisation sur la carte')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseDatabase.instance.ref('mecaniciens/$uid').update({
        'nomGarage': _nomGarageController.text.trim(),
        'adresseGarage': _adresseController.text.trim(),
        'specialite': _specialite,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'statutCompte': 'en_revision',
      });
      setState(() => _hasSubmitted = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSubmitted) {
      return _buildWaitingView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Compléter votre profil', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await AuthService.logout();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dernière étape !',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Veuillez renseigner les informations de votre garage pour l\'approbation.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
              ),
              const SizedBox(height: 32),
              
              _buildLabel('Nom de votre garage'),
              TextFormField(
                controller: _nomGarageController,
                decoration: _inputDecoration(''),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              
              const SizedBox(height: 20),
              
              _buildLabel('Spécialité'),
              DropdownButtonFormField<String>(
                value: _specialite,
                items: _specialties.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _specialite = val),
                decoration: _inputDecoration('Choisir une spécialité'),
                validator: (v) => v == null ? 'Requis' : null,
              ),

              const SizedBox(height: 20),

              _buildLabel('Adresse (auto-complétée par la carte)'),
              TextFormField(
                controller: _adresseController,
                decoration: _inputDecoration('Adresse du garage'),
                maxLines: 2,
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),

              const SizedBox(height: 24),
              
              _buildLabel('Localisation du garage'),
              const SizedBox(height: 8),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedLocation ?? const LatLng(36.8, 10.1),
                          initialZoom: 13,
                          onTap: (tapPosition, point) {
                            setState(() {
                              _selectedLocation = point;
                            });
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
                                  width: 50,
                                  height: 50,
                                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                ),
                              ],
                            ),
                        ],
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white,
                          onPressed: _isLoadingGps ? null : _determinePosition,
                          child: _isLoadingGps 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location, color: Color(0xFF3B82F6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Appuyez sur la carte ou utilisez le bouton GPS pour localiser votre garage.', 
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
              ),

              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Soumettre le profil', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
    );
  }

  Widget _buildWaitingView() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: Icon(Icons.hourglass_empty_rounded, size: 64, color: Colors.orange.shade600),
              ),
              const SizedBox(height: 32),
              const Text('Profil en cours de révision', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 16),
              const Text(
                'Vos informations ont été transmises. Un administrateur va valider votre compte sous peu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await AuthService.logout();
                    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
