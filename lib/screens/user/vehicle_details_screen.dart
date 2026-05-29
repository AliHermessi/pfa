import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../models/carnet_entretien.dart';
import '../../services/vehicle_service.dart';
import '../../services/notification_service.dart';
import '../../services/carnet_service.dart';
import '../../models/app_notification.dart';
import 'add_vehicle_screen.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailsScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  late Vehicle _vehicle;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
  }

  Future<void> _updateMileage(int newMileage) async {
    final updatedVehicle = Vehicle(
      id: _vehicle.id,
      marque: _vehicle.marque,
      modele: _vehicle.modele,
      immatriculation: _vehicle.immatriculation,
      kilometrageActuel: newMileage,
      kilometrageProchVidange: _vehicle.kilometrageProchVidange,
      prochainControle: _vehicle.prochainControle,
      sante: _vehicle.sante, // We don't update sante directly anymore, it's calculated from carnet
      clientId: _vehicle.clientId,
      dernierMiseAJourKm: DateTime.now(),
      rappelKmJours: _vehicle.rappelKmJours,
    );

    try {
      await VehicleService.updateVehicle(updatedVehicle);
      setState(() {
        _vehicle = updatedVehicle;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kilométrage mis à jour')),
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

  void _showMileageDialog() {
    final controller = TextEditingController(text: _vehicle.kilometrageActuel.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mettre à jour le kilométrage'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nouveau kilométrage',
            suffixText: 'km',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text);
              if (newValue != null) {
                Navigator.pop(context);
                _updateMileage(newValue);
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title: Text(_vehicle.nomComplet, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddVehicleScreen(vehicle: _vehicle))),
          ),
        ],
      ),
      body: StreamBuilder<List<CarnetEntretien>>(
        stream: CarnetService.vehicleCarnetStream(_vehicle.id),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          final health = CarnetService.calculateHealth(_vehicle, entries);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainInfoCard(),
                const SizedBox(height: 16),
                _buildMaintenanceStatus(health),
                const SizedBox(height: 16),
                _buildLastEntries(entries),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.directions_car, color: Color(0xFF1976D2), size: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_vehicle.marque, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      Text(_vehicle.modele, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                        child: Text(_vehicle.immatriculation.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow(Icons.speed, 'Kilométrage Actuel', '${_vehicle.kilometrageActuel} km', isClickable: true, onTap: _showMileageDialog),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.calendar_today, 'Prochain Contrôle', _vehicle.prochainControle.year > 2000 ? DateFormat('dd/MM/yyyy').format(_vehicle.prochainControle) : 'Non planifié'),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceStatus(double? health) {
    final bool isComplete = health != null;
    final displayHealth = health ?? 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statut de maintenance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Santé Générale'),
                if (isComplete)
                  Text('${(displayHealth * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: displayHealth < 0.5 ? Colors.orange : Colors.green))
                else
                  const Text('Incomplet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            if (isComplete)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: displayHealth,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(displayHealth < 0.5 ? Colors.orange : Colors.green),
                ),
              )
            else
              const Text('Renseignez au moins 4 composants pour voir votre score santé.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildLastEntries(List<CarnetEntretien> entries) {
    if (entries.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Derniers entretiens', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ...entries.take(5).map((e) => ListTile(
          leading: const Icon(Icons.history, size: 20),
          title: Text(e.nomComposantCustom ?? 'Composant'),
          subtitle: Text('${e.dernierKilometrageChangement} km - ${DateFormat('dd/MM/yyyy').format(e.dateChangement)}'),
          dense: true,
        )),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isClickable = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isClickable ? const Color(0xFF1976D2) : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
