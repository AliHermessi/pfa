import 'package:flutter/material.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'user_dashboard_screen.dart';
import 'add_vehicle_screen.dart';
import 'historique_screen.dart';
import 'calendrier_screen.dart';
import 'mecaniciens_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  int _currentIndex = 1;

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    Widget screen;
    switch (index) {
      case 0:
        screen = const UserDashboardScreen();
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
        context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _deleteVehicle(String id) async {
    try {
      await VehicleService.deleteVehicle(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Véhicule supprimé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  void _navigateToAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        automaticallyImplyLeading: false,
        title: const Text(
          'Mes Véhicules',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToAdd,
          ),
        ],
      ),
      body: StreamBuilder<List<Vehicle>>(
        stream: VehicleService.vehiclesStream(),
        builder: (context, snapshot) {
          // ── Chargement ─────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── Erreur ─────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }

          final vehicles = snapshot.data ?? [];

          // ── Aucun véhicule ─────────────────────────────────────────────
          if (vehicles.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aucun véhicule ajouté',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // ── Liste des véhicules ────────────────────────────────────────
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            itemBuilder: (_, i) => _VehicleCard(
              vehicle: vehicles[i],
              onDelete: () => _deleteVehicle(vehicles[i].id),
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddVehicleScreen(vehicle: vehicles[i]),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAdd,
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: UserBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ── Vehicle Card ─────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _VehicleCard({
    required this.vehicle,
    required this.onDelete,
    required this.onEdit,
  });

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bool isWarning = vehicle.vidangeUrgente || vehicle.sante < 0.5;
    final Color headerColor =
        isWarning ? const Color(0xFFE65100) : const Color(0xFF1976D2);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _capitalize(vehicle.nomComplet),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        vehicle.immatriculation.toUpperCase(),
                        style: TextStyle(
                            color: headerColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text('Supprimer',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.speed_outlined,
                  label: 'Kilométrage',
                  value:
                      '${vehicle.kilometrage.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.oil_barrel_outlined,
                  label: 'Prochaine vidange',
                  value: vehicle.vidangeUrgente
                      ? '${vehicle.kmAvantVidange.abs()} km dépassé !'
                      : '+ ${vehicle.kmAvantVidange} km',
                  valueColor: vehicle.vidangeUrgente
                      ? const Color(0xFFE65100)
                      : const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.healing_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Santé générale',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    Text(
                      '${(vehicle.sante * 100).toInt()}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: vehicle.sante < 0.5
                              ? const Color(0xFFE65100)
                              : const Color(0xFF1976D2)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: vehicle.sante,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      vehicle.sante < 0.5
                          ? const Color(0xFFE65100)
                          : const Color(0xFF1976D2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87)),
      ],
    );
  }
}
