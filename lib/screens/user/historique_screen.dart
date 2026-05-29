import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/intervention.dart';
import '../../models/carnet_entretien.dart';
import '../../models/vehicle.dart';
import '../../services/intervention_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/carnet_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'user_dashboard_screen.dart';
import 'vehicles_screen.dart';
import 'calendrier_screen.dart';
import 'mecaniciens_screen.dart';
import '../chat_screen.dart';

class HistoriqueScreen extends StatefulWidget {
  final String? vehicleId; 
  const HistoriqueScreen({super.key, this.vehicleId});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoryItem {
  final DateTime date;
  final String title;
  final String subtitle;
  final String vehicleName;
  final double price;
  final bool isIntervention;
  final String category; // 'PIECE', 'FLUIDE', 'CONTROLE', 'AUTRE'
  final dynamic data; 

  _HistoryItem({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.vehicleName,
    this.price = 0,
    required this.isIntervention,
    required this.category,
    required this.data,
  });
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  final int _currentIndex = 2;
  String _selectedCategory = 'Tous';
  String? _selectedVehicleId;

  final Map<String, String> _categoryFilters = {
    'Tous': 'Tous',
    'PIECE': 'Pièces',
    'FLUIDE': 'Fluides',
    'CONTROLE': 'Contrôles',
    'AUTRE': 'Autres',
  };

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.vehicleId;
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    Widget screen;
    switch (index) {
      case 0:
        screen = const UserDashboardScreen();
        break;
      case 1:
        screen = const VehiclesScreen();
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

  String _mapTaskToCategory(InterventionTask? task) {
    if (task == null) return 'PIECE';
    switch (task.type) {
      case InterventionType.fluide:
        return 'FLUIDE';
      case InterventionType.controle:
        return 'CONTROLE';
      case InterventionType.autre:
        return 'AUTRE';
      default:
        return 'PIECE';
    }
  }

  List<_HistoryItem> _buildUnifiedHistory(
    List<Intervention> interventions,
    Map<String, List<CarnetEntretien>> carnets,
    List<Vehicle> vehicles,
  ) {
    List<_HistoryItem> items = [];

    for (var i in interventions) {
      if (_selectedVehicleId != null && i.vehiculeId != _selectedVehicleId) continue;
      
      final firstTask = i.tasks.isNotEmpty ? i.tasks.first : null;

      items.add(_HistoryItem(
        date: i.date,
        title: i.typeLabel,
        subtitle: i.mecanicienNom != null ? '🔧 Réparé par ${i.mecanicienNom}' : (firstTask?.description ?? ''),
        vehicleName: i.vehiculeNom,
        price: i.prixEstime,
        isIntervention: true,
        category: _mapTaskToCategory(firstTask),
        data: i,
      ));
    }

    carnets.forEach((vId, entries) {
      if (_selectedVehicleId != null && vId != _selectedVehicleId) return;
      
      final vehicle = vehicles.firstWhere(
        (v) => v.id == vId, 
        orElse: () => Vehicle(
          id: '', 
          marque: 'Véhicule', 
          modele: '', 
          immatriculation: '', 
          kilometrageActuel: 0, 
          kilometrageProchVidange: 0, 
          prochainControle: DateTime.now(), 
          sante: 0, 
          clientId: '',
          dernierMiseAJourKm: DateTime.now(),
        )
      );
      
      for (var entry in entries) {
        items.add(_HistoryItem(
          date: entry.dateChangement,
          title: entry.nomComposantCustom ?? 'Entretien',
          subtitle: '📍 Effectué à ${entry.dernierKilometrageChangement} km',
          vehicleName: vehicle.nomComplet,
          isIntervention: false,
          category: entry.categorie,
          data: entry,
        ));
      }
    });

    return items.where((item) {
      if (_selectedCategory == 'Tous') return true;
      return item.category == _selectedCategory;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        automaticallyImplyLeading: widget.vehicleId != null,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.vehicleId != null ? 'Historique Véhicule' : 'Journal d\'entretien',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<List<Vehicle>>(
        stream: VehicleService.vehiclesStream(),
        builder: (context, vSnapshot) {
          if (!vSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final vehicles = vSnapshot.data ?? [];
          
          return StreamBuilder<List<Intervention>>(
            stream: InterventionService.interventionsStream(),
            builder: (context, iSnapshot) {
              final interventions = iSnapshot.data ?? [];

              return FutureBuilder<Map<String, List<CarnetEntretien>>>(
                future: _loadAllCarnets(vehicles),
                builder: (context, cSnapshot) {
                  if (cSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final carnets = cSnapshot.data ?? {};
                  final history = _buildUnifiedHistory(interventions, carnets, vehicles);

                  return Column(
                    children: [
                      _buildCategoryFilter(),
                      if (vehicles.length > 1 && widget.vehicleId == null)
                        _buildVehicleFilter(vehicles),
                      Expanded(
                        child: history.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: history.length,
                                itemBuilder: (context, index) => _HistoryCard(item: history[index]),
                              ),
                      ),
                    ],
                  );
                }
              );
            },
          );
        }
      ),
      bottomNavigationBar: widget.vehicleId == null 
        ? UserBottomNavBar(currentIndex: _currentIndex, onTap: _onNavTap)
        : null,
    );
  }

  Future<Map<String, List<CarnetEntretien>>> _loadAllCarnets(List<Vehicle> vehicles) async {
    final List<Future<List<CarnetEntretien>>> futures = vehicles.map((v) => CarnetService.vehicleCarnetStream(v.id).first).toList();
    final results = await Future.wait(futures);
    
    Map<String, List<CarnetEntretien>> all = {};
    for (int i = 0; i < vehicles.length; i++) {
      all[vehicles[i].id] = results[i];
    }
    return all;
  }

  Widget _buildCategoryFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _categoryFilters.entries.map((entry) {
            final isActive = _selectedCategory == entry.key;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF1976D2) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isActive ? const Color(0xFF1976D2) : Colors.grey.shade300),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive ? Colors.white : Colors.grey.shade700,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVehicleFilter(List<Vehicle> vehicles) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DropdownButtonHideUnderline(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButton<String>(
            value: _selectedVehicleId,
            hint: const Text('Sélectionner un véhicule', style: TextStyle(fontSize: 13)),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('Tous mes véhicules')),
              ...vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.nomComplet))),
            ],
            onChanged: (val) => setState(() => _selectedVehicleId = val),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Aucun historique trouvé', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (item.isIntervention)
                      Text('${item.price.toInt()} DT', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2), fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.vehicleName, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(item.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.event, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMMM yyyy').format(item.date),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    _buildCategoryBadge(),
                  ],
                ),
              ],
            ),
          ),
          if (item.isIntervention)
            IconButton(
              icon: Icon(Icons.chat_bubble_outline, color: Colors.blue.shade300, size: 20),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(intervention: item.data as Intervention))),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge() {
    Color color = Colors.grey;
    String label = 'Autre';
    
    switch (item.category) {
      case 'PIECE':
        color = Colors.blue;
        label = 'Pièce';
        break;
      case 'FLUIDE':
        color = Colors.cyan;
        label = 'Fluide';
        break;
      case 'CONTROLE':
        color = Colors.orange;
        label = 'Contrôle';
        break;
      case 'AUTRE':
        color = Colors.purple;
        label = 'Autre';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildIcon() {
    IconData iconData = Icons.build_circle_outlined;
    Color color = Colors.grey;

    final title = item.title.toLowerCase();
    if (title.contains('vidange') || title.contains('huile') || item.category == 'FLUIDE') {
      iconData = Icons.oil_barrel_outlined;
      color = Colors.orange;
    } else if (title.contains('pneu')) {
      iconData = Icons.tire_repair_outlined;
      color = Colors.green;
    } else if (title.contains('batterie')) {
      iconData = Icons.battery_charging_full_outlined;
      color = Colors.blue;
    } else if (title.contains('frein')) {
      iconData = Icons.disc_full_outlined;
      color = Colors.red;
    } else if (item.category == 'AUTRE') {
      iconData = Icons.miscellaneous_services;
      color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }
}
