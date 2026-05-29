import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/vehicle.dart';
import '../../models/intervention.dart';
import '../../services/vehicle_service.dart';
import '../../services/intervention_service.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_service.dart';
import 'notifications_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'vehicles_screen.dart';
import 'historique_screen.dart';
import 'calendrier_screen.dart';
import 'mecaniciens_screen.dart';
import 'profile_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  final int _currentIndex = 0;
  
  late final Stream<List<AppNotification>> _notificationsStream;
  late final Stream<List<Vehicle>> _vehiclesStream;
  late final Stream<List<Intervention>> _interventionsStream;

  bool _isTracking = false;
  String? _trackingVehicleName;
  StreamSubscription? _serviceSubscription;

  @override
  void initState() {
    super.initState();
    _notificationsStream = NotificationService.getUserNotificationsStream();
    _vehiclesStream = VehicleService.vehiclesStream();
    _interventionsStream = InterventionService.interventionsStream();
    
    _checkServiceStatus();

    // Check for reminders when dashboard is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReminderService.checkAndGenerateReminders();
    });
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterBackgroundService().isRunning();
    if (mounted) {
      setState(() {
        _isTracking = isRunning;
      });
    }
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Utilisateur';
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim().split(' ').first;
    }
    return user.email?.split('@').first ?? 'Utilisateur';
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    Widget screen;
    switch (index) {
      case 1:
        screen = const VehiclesScreen();
        break;
      case 2:
        screen = const HistoriqueScreen();
        break;
      case 3:
        screen = const CalendrierScreen();
        break;
      case 4:
        screen = const MecaniciensScreen();
        break;
      default:
        return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _toggleTracking(List<Vehicle> vehicles) async {
    if (_isTracking) {
      FlutterBackgroundService().invoke('stopService');
      setState(() {
        _isTracking = false;
        _trackingVehicleName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mode conduite arrêté. Kilométrage synchronisé.')),
      );
      return;
    }

    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter un véhicule d\'abord.')),
      );
      return;
    }

    // Request permissions
    final status = await Permission.locationAlways.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission de localisation (Toujours) requise pour le suivi.')),
      );
      return;
    }

    if (vehicles.length == 1) {
      _startService(vehicles.first);
    } else {
      _showVehicleSelectionDialog(vehicles);
    }
  }

  void _showVehicleSelectionDialog(List<Vehicle> vehicles) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choisir un véhicule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: vehicles.map((v) => ListTile(
            title: Text(v.nomComplet),
            subtitle: Text(v.immatriculation),
            onTap: () {
              Navigator.pop(ctx);
              _startService(v);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _startService(Vehicle vehicle) async {
    final service = FlutterBackgroundService();
    await service.startService();
    service.invoke('setVehicle', {
      'vehicleId': vehicle.id,
      'userId': FirebaseAuth.instance.currentUser?.uid,
    });
    setState(() {
      _isTracking = true;
      _trackingVehicleName = vehicle.nomComplet;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        automaticallyImplyLeading: false,
        elevation: 0,
        title: const Text(
          'AutoCare',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder<List<AppNotification>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? [];
              final unreadCount = notifications.where((n) => !n.estLu).length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white24,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
            ),
            tooltip: 'Mon Profil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Vehicle>>(
        stream: _vehiclesStream,
        builder: (context, vehiclesSnapshot) {
          return StreamBuilder<List<Intervention>>(
            stream: _interventionsStream,
            builder: (context, interventionsSnapshot) {
              if (vehiclesSnapshot.hasError || interventionsSnapshot.hasError) {
                return const Center(child: Text("Une erreur est survenue"));
              }
              if (vehiclesSnapshot.connectionState == ConnectionState.waiting || interventionsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final vehicles = vehiclesSnapshot.data ?? [];
              final interventions = interventionsSnapshot.data ?? [];
              
              final alertVehicles = vehicles
                  .where((v) => v.vidangeUrgente)
                  .toList();
                  
              final recentInterventions = interventions.take(3).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour, $_userName 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tracking Card
                    _buildTrackingCard(vehicles),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        _StatCard(
                          value: vehicles.length.toString(),
                          label: 'Véhicules',
                          color: const Color(0xFF1976D2),
                          icon: Icons.directions_car,
                          onTap: () => _onNavTap(1),
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: alertVehicles.length.toString(), 
                          label: 'Alertes',
                          color: const Color(0xFFE65100),
                          icon: Icons.warning_amber_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(initialFilter: NotificationGravite.alerte),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: interventions.length.toString(),
                          label: 'Interventions',
                          color: const Color(0xFF2E7D32),
                          icon: Icons.build,
                          onTap: () => _onNavTap(2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (alertVehicles.isNotEmpty) ...[
                      const Text(
                        'Rappels de Vidange',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...alertVehicles.map((v) => _AlertCard(
                        vehicle: v,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(initialFilter: NotificationGravite.alerte),
                          ),
                        ),
                      )),
                      const SizedBox(height: 24),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Interventions récentes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => _onNavTap(2),
                          child: const Text('Voir tout',
                              style:
                                  TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (recentInterventions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Aucune intervention récente',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...recentInterventions
                          .map((i) => _InterventionCard(
                            intervention: i, 
                            onTap: () => _onNavTap(2)
                          )),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: UserBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildTrackingCard(List<Vehicle> vehicles) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _isTracking ? Colors.green.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isTracking ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isTracking ? Icons.location_on : Icons.directions_run,
                color: _isTracking ? Colors.green : Colors.blue,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isTracking ? 'Mode Conduite Actif' : 'Calcul Automatique KM',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isTracking ? Colors.green.shade700 : Colors.black87,
                    ),
                  ),
                  Text(
                    _isTracking 
                      ? 'Suivi en cours pour : ${_trackingVehicleName ?? 'Véhicule'}'
                      : 'Utilisez le GPS pour mettre à jour votre kilométrage',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _toggleTracking(vehicles),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? Colors.red : const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_isTracking ? 'STOP' : 'START'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;
  const _AlertCard({required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      color: const Color(0xFFFFF3E0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE65100), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.nomComplet,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFFBF360C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vidange due (${vehicle.kmAvantVidange.abs()} km dépassé)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFE65100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterventionCard extends StatelessWidget {
  final Intervention intervention;
  final VoidCallback onTap;
  const _InterventionCard({required this.intervention, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.build_circle_outlined,
                    color: Color(0xFF1976D2), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intervention.typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${intervention.vehiculeNom} · ${DateFormat('dd MMM yyyy').format(intervention.date)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
