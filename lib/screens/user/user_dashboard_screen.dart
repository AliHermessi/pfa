import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/vehicle.dart';
import '../../models/intervention.dart';
import '../../services/vehicle_service.dart';
import '../../services/intervention_service.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import 'notifications_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'vehicles_screen.dart';
import 'historique_screen.dart';
import 'calendrier_screen.dart';
import 'mecaniciens_screen.dart';
import '../chat_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _currentIndex = 0;
  
  late final Stream<List<AppNotification>> _notificationsStream;
  late final Stream<List<Vehicle>> _vehiclesStream;
  late final Stream<List<Intervention>> _interventionsStream;

  @override
  void initState() {
    super.initState();
    _notificationsStream = NotificationService.getUserNotificationsStream();
    _vehiclesStream = VehicleService.vehiclesStream();
    _interventionsStream = InterventionService.interventionsStream();
  }

  // ── Nom de l'utilisateur connecté ────────────────────────────────────────
  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Utilisateur';
    // Utilise le displayName si disponible, sinon la partie avant @ de l'email
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim().split(' ').first; // Prénom seulement
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

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        automaticallyImplyLeading: false,
        title: const Text(
          'AutoCare',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder<List<AppNotification>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? [];
              final unreadCount = notifications.where((n) => !n.lue).length;
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
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Déconnexion',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Vehicle>>(
        stream: _vehiclesStream,
        builder: (context, vehiclesSnapshot) {
          return StreamBuilder<List<Intervention>>(
            stream: _interventionsStream,
            builder: (context, interventionsSnapshot) {
              if (vehiclesSnapshot.hasError) {
                return Center(child: Text("Erreur Vehicules: ${vehiclesSnapshot.error}", style: const TextStyle(color: Colors.red)));
              }
              if (interventionsSnapshot.hasError) {
                return Center(child: Text("Erreur Interventions: ${interventionsSnapshot.error}", style: const TextStyle(color: Colors.red)));
              }
              if (vehiclesSnapshot.connectionState == ConnectionState.waiting || interventionsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final vehicles = vehiclesSnapshot.data ?? [];
              final interventions = interventionsSnapshot.data ?? [];
              final alertVehicles = vehicles
                  .where((v) => v.vidangeUrgente || v.sante < 0.5)
                  .toList();
              final recentInterventions = interventions.take(3).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting ──────────────────────────────────────────
                    Text(
                      'Bonjour, $_userName 👋',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Voici l\'état de vos véhicules',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // ── Stats cards ───────────────────────────────────────
                    Row(
                      children: [
                        _StatCard(
                          value: vehicles.length.toString(),
                          label: 'Véhicules',
                          color: const Color(0xFF1976D2),
                          icon: Icons.directions_car,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          value: alertVehicles.length.toString(),
                          label: 'Alertes',
                          color: const Color(0xFFE65100),
                          icon: Icons.warning_amber_rounded,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          value: interventions.length.toString(),
                          label: 'Interventions',
                          color: const Color(0xFF2E7D32),
                          icon: Icons.build,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Alertes ───────────────────────────────────────────
                    if (alertVehicles.isNotEmpty) ...[
                      const Text(
                        'Alertes urgentes',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...alertVehicles.map((v) => _AlertCard(vehicle: v)),
                      const SizedBox(height: 20),
                    ],

                    // ── Interventions récentes ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Interventions récentes',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => _onNavTap(2),
                          child: const Text('Voir tout',
                              style:
                                  TextStyle(color: Color(0xFF1976D2))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (recentInterventions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Aucune intervention récente',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...recentInterventions
                          .map((i) => _InterventionCard(intervention: i)),
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
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Vehicle vehicle;
  const _AlertCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border:
            Border(left: BorderSide(color: const Color(0xFFE65100), width: 3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE65100), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              vehicle.vidangeUrgente
                  ? '⚠ Vidange due — ${vehicle.nomComplet} (${vehicle.kmAvantVidange.abs()} km dépassé)'
                  : '⚠ Santé faible — ${vehicle.nomComplet} (${(vehicle.sante * 100).toInt()}%)',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFFBF360C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterventionCard extends StatelessWidget {
  final Intervention intervention;
  const _InterventionCard({required this.intervention});

  Color get _statutColor {
    switch (intervention.statut) {
      case InterventionStatut.termine:
        return const Color(0xFF2E7D32);
      case InterventionStatut.enCours:
        return const Color(0xFF1976D2);
      case InterventionStatut.planifie:
        return const Color(0xFFE65100);
      case InterventionStatut.enAttente:
        return Colors.orange;
      case InterventionStatut.annule:
        return Colors.red;
    }
  }

  Color get _statutBg {
    switch (intervention.statut) {
      case InterventionStatut.termine:
        return const Color(0xFFE8F5E9);
      case InterventionStatut.enCours:
        return const Color(0xFFE3F2FD);
      case InterventionStatut.planifie:
        return const Color(0xFFFFF3E0);
      case InterventionStatut.enAttente:
        return Colors.orange.shade50;
      case InterventionStatut.annule:
        return Colors.red.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intervention.typeLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${intervention.vehiculeNom} · ${intervention.date.day}/${intervention.date.month}/${intervention.date.year}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statutBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  intervention.statutLabel,
                  style: TextStyle(
                      fontSize: 11,
                      color: _statutColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (intervention.statut == InterventionStatut.planifie || intervention.statut == InterventionStatut.enCours) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(intervention: intervention)),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Discuter avec le mécanicien', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                  side: const BorderSide(color: Color(0xFF1976D2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
