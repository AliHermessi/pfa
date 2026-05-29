import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../models/carnet_entretien.dart';
import '../../services/vehicle_service.dart';
import '../../services/carnet_service.dart';
import 'add_vehicle_screen.dart';
import 'ai_diagnostic_screen.dart';

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
    if (newMileage == _vehicle.kilometrageActuel) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await VehicleService.updateVehicleMileage(uid, _vehicle.id, newMileage);
      
      final updated = await VehicleService.getVehicle(uid, _vehicle.id);
      if (updated != null && mounted) {
        setState(() {
          _vehicle = updated;
        });
      }

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
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AddVehicleScreen(vehicle: _vehicle)));
              // Refresh after edit
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                final updated = await VehicleService.getVehicle(uid, _vehicle.id);
                if (updated != null && mounted) setState(() => _vehicle = updated);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<CarnetEntretien>>(
        stream: CarnetService.vehicleCarnetStream(_vehicle.id),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainInfoCard(),
                if (_vehicle.imageUrls.isNotEmpty) _buildImageSection(),
                const SizedBox(height: 16),
                _buildAIDiagnosticCard(),
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

  Widget _buildImageSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photos du véhicule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _vehicle.imageUrls.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => showDialog(context: context, builder: (_) => Dialog(child: Image.network(_vehicle.imageUrls[index]))),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(image: NetworkImage(_vehicle.imageUrls[index]), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIDiagnosticCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100, width: 1.5),
      ),
      color: Colors.blue.shade50.withOpacity(0.5),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AIDiagnosticScreen(vehicle: _vehicle),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF1976D2), size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diagnostic Santé IA',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1976D2)),
                    ),
                    Text(
                      'Analyse complète (Historique + Photos)',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF1976D2)),
            ],
          ),
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
