import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/mecanicien.dart';
import 'intervention_form_screen.dart';
import 'mecanicien_details_screen.dart';

class CarteMecaniciensScreen extends StatefulWidget {
  const CarteMecaniciensScreen({super.key});

  @override
  State<CarteMecaniciensScreen> createState() => _CarteMecaniciensScreenState();
}

class _CarteMecaniciensScreenState extends State<CarteMecaniciensScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  static const LatLng _defaultCenter = LatLng(36.8190, 10.1658);
  LatLng _center = _defaultCenter;
  double _zoom = 13.0;

  LatLng? _userPosition;

  List<Mecanicien> _mecaniciens = [];
  StreamSubscription? _dbSubscription;

  bool _disponiblesOnly = false;
  Mecanicien? _selectedMecanicien;
  bool _loadingGps = true;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(_pulseController);

    _getUserLocation();
    _listenMecaniciens();
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() => _loadingGps = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() => _loadingGps = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final userLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userPosition = userLatLng;
        _center = userLatLng;
        _zoom = 14.0;
        _loadingGps = false;
      });

      _mapController.move(userLatLng, 14.0);
    } catch (_) {
      setState(() => _loadingGps = false);
    }
  }

  void _listenMecaniciens() {
    final ref = FirebaseDatabase.instance.ref('mecaniciens');
    _dbSubscription = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;

      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .where((e) => e.value is Map)
          .map((e) => Mecanicien.fromMap(e.key as String, e.value as Map))
          .where((m) => m.isApproved)
          .toList();

      if (mounted) setState(() => _mecaniciens = list);
    });
  }

  List<Mecanicien> get _filtered {
    return _disponiblesOnly
        ? _mecaniciens.where((m) => m.disponible).toList()
        : _mecaniciens;
  }

  LatLng _getMecanicienPosition(Mecanicien m) {
    if (m.latitude != null && m.longitude != null) {
      return LatLng(m.latitude!, m.longitude!);
    }
    final double offsetLat = (m.id.hashCode % 100) * 0.0004 - 0.02;
    final double offsetLng = (m.id.hashCode % 80) * 0.0004 - 0.016;
    return LatLng(_defaultCenter.latitude + offsetLat, _defaultCenter.longitude + offsetLng);
  }

  int get _avecPosition => _mecaniciens.where((m) => m.hasLiveLocation).length;

  void _centerOnUser() {
    if (_userPosition != null) {
      _mapController.move(_userPosition!, 15.0);
    } else {
      _getUserLocation();
    }
  }

  void _choisirMecanicien(Mecanicien m) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InterventionFormScreen(initialMecanicien: m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Carte — Mécaniciens',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                const SizedBox(width: 6),
                Text(
                  '$_avecPosition en ligne',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _disponiblesOnly = !_disponiblesOnly),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _disponiblesOnly ? Colors.white : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: _disponiblesOnly ? const Color(0xFF1565C0) : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Disponibles seulement',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _disponiblesOnly ? const Color(0xFF1565C0) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _LegendDot(color: Colors.green.shade400, label: 'En ligne'),
                const SizedBox(width: 12),
                _LegendDot(color: Colors.red.shade400, label: 'Hors ligne'),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: _zoom,
                      onTap: (_, __) => setState(() => _selectedMecanicien = null),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.vroomlog.app',
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          if (_userPosition != null)
                            Marker(
                              point: _userPosition!,
                              width: 44,
                              height: 44,
                              child: AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (_, __) => Transform.scale(
                                  scale: _pulseAnim.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.25),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.blue, width: 2.5),
                                    ),
                                    child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 28),
                                  ),
                                ),
                              ),
                            ),
                          ..._filtered.map((m) {
                            final isSelected = _selectedMecanicien?.id == m.id;
                            final pos = _getMecanicienPosition(m);
                            final isOnline = m.hasLiveLocation;
                            return Marker(
                              point: pos,
                              width: isSelected ? 56 : 46,
                              height: isSelected ? 56 : 46,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selectedMecanicien = m);
                                  _mapController.move(pos, 15.5);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.green.shade400 : Colors.red.shade400,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isOnline ? Colors.green : Colors.red).withValues(alpha: 0.4),
                                        blurRadius: isSelected ? 12 : 6,
                                        spreadRadius: isSelected ? 3 : 1,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.build_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const RichAttributionWidget(
                        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 14,
                    bottom: _selectedMecanicien != null ? 240 : 20,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'zoomIn',
                          backgroundColor: Colors.white,
                          elevation: 4,
                          onPressed: () {
                            _zoom = (_zoom + 1).clamp(3.0, 19.0);
                            _mapController.move(_mapController.camera.center, _zoom);
                          },
                          child: const Icon(Icons.add, color: Color(0xFF1565C0)),
                        ),
                        const SizedBox(height: 6),
                        FloatingActionButton.small(
                          heroTag: 'zoomOut',
                          backgroundColor: Colors.white,
                          elevation: 4,
                          onPressed: () {
                            _zoom = (_zoom - 1).clamp(3.0, 19.0);
                            _mapController.move(_mapController.camera.center, _zoom);
                          },
                          child: const Icon(Icons.remove, color: Color(0xFF1565C0)),
                        ),
                        const SizedBox(height: 6),
                        FloatingActionButton.small(
                          heroTag: 'myPos',
                          backgroundColor: const Color(0xFF1565C0),
                          elevation: 4,
                          onPressed: _loadingGps ? null : _centerOnUser,
                          child: _loadingGps
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.my_location, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (_avecPosition == 0 && _mecaniciens.isNotEmpty)
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(24)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, color: Colors.white70, size: 16),
                              SizedBox(width: 8),
                              Text("Aucun mécanicien n'a partagé sa position", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_selectedMecanicien != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _MecanicienPanel(
                        mecanicien: _selectedMecanicien!,
                        onChoisir: () => _choisirMecanicien(_selectedMecanicien!),
                        onClose: () => setState(() => _selectedMecanicien = null),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _MecanicienPanel extends StatelessWidget {
  final Mecanicien mecanicien;
  final VoidCallback onChoisir;
  final VoidCallback onClose;

  const _MecanicienPanel({required this.mecanicien, required this.onChoisir, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MecanicienDetailsScreen(mecanicien: mecanicien)),
                        );
                      },
                      child: CircleAvatar(
                        radius: 27,
                        backgroundColor: const Color(0xFF1565C0),
                        child: Text(mecanicien.initiales, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(mecanicien.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: mecanicien.disponible ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 7, color: mecanicien.disponible ? Colors.green : Colors.red),
                                    const SizedBox(width: 4),
                                    Text(
                                      mecanicien.disponible ? 'Disponible' : 'Occupé',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: mecanicien.disponible ? Colors.green.shade700 : Colors.red.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(mecanicien.specialite, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              ...List.generate(5, (i) => Icon(
                                i < mecanicien.note.floor() ? Icons.star : i < mecanicien.note ? Icons.star_half : Icons.star_border,
                                color: const Color(0xFFFFB300),
                                size: 14,
                              )),
                              const SizedBox(width: 4),
                              Text('${mecanicien.note.toStringAsFixed(1)} (${mecanicien.nombreAvis} avis)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.grey, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (mecanicien.hasLiveLocation)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, color: Colors.green, size: 14),
                            SizedBox(width: 4),
                            Text('En direct', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: mecanicien.disponible ? onChoisir : null,
                      icon: const Icon(Icons.build_circle, size: 16, color: Colors.white),
                      label: const Text('Choisir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
