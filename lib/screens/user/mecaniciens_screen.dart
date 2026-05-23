import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/mecanicien.dart';
import '../../models/intervention.dart';

import '../widgets/bottom_nav_bar.dart';

import 'user_dashboard_screen.dart';
import 'vehicles_screen.dart';
import 'historique_screen.dart';
import 'calendrier_screen.dart';
import 'intervention_form_screen.dart';
import 'carte_mecaniciens_screen.dart';

class MecaniciensScreen extends StatefulWidget {
  const MecaniciensScreen({super.key});

  @override
  State<MecaniciensScreen> createState() => _MecaniciensScreenState();
}

class _MecaniciensScreenState extends State<MecaniciensScreen> {
  int _currentIndex = 4;
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _filters = ['Tous', 'Proche', 'Disponible', '5 étoiles'];

  // ── Données réelles depuis Firebase ───────────────────────────────────────
  Stream<List<Mecanicien>> _getMecaniciensStream() {
    return FirebaseDatabase.instance.ref('mecaniciens').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .where((e) => e.value is Map)
          .map((e) => Mecanicien.fromMap(e.key as String, e.value as Map))
          .where((m) => m.isApproved) // Seulement les mécaniciens approuvés
          .toList();
      return list;
    });
  }

  List<Mecanicien> _applyFilters(List<Mecanicien> list) {
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((m) =>
              m.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              m.specialite.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    switch (_selectedFilter) {
      case 'Proche':
        list = [...list]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case 'Disponible':
        list = list.where((m) => m.disponible).toList();
        break;
      case '5 étoiles':
        list = list.where((m) => m.note >= 4.8).toList();
        break;
    }

    return list;
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
      case 2:
        screen = const HistoriqueScreen();
        break;
      case 3:
        screen = const CalendrierScreen();
        break;
      default:
        return;
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => screen));
  }

  void _choisirMecanicien(Mecanicien m) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InterventionFormScreen(
          intervention: Intervention(
            id: '',
            vehiculeId: '',
            vehiculeNom: '',
            userId: '',
            type: InterventionType.vidange,
            description: '',
            pieces: [],
            prixEstime: 0,
            date: DateTime.now(),
            statut: InterventionStatut.enAttente,
            mecanicienId: m.id,
            mecanicienNom: m.nom,
          ),
        ),
      ),
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
          'Mécaniciens',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // ── Bouton bascule vers la carte ────────────────────────────
          Tooltip(
            message: 'Voir sur la carte',
            child: IconButton(
              icon: const Icon(Icons.map_outlined, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CarteMecaniciensScreen(),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 16),
                const SizedBox(width: 2),
                const Text('Ariana',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search + Filtres ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un mécanicien...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide:
                          const BorderSide(color: Color(0xFF1976D2), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((f) {
                      final isActive = _selectedFilter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF1976D2)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF1976D2)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Mecanicien>>(
              stream: _getMecaniciensStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final allMecaniciens = snapshot.data ?? [];
                final filtered = _applyFilters(allMecaniciens);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.build_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Aucun mécanicien trouvé',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _MecanicienCard(
                    mecanicien: filtered[i],
                    onChoisir: () => _choisirMecanicien(filtered[i]),
                  ),
                );
              },
            ),
          ),

        ],
      ),
      bottomNavigationBar: UserBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ── Mecanicien Card ──────────────────────────────────────────────────────────

class _MecanicienCard extends StatelessWidget {
  final Mecanicien mecanicien;
  final VoidCallback onChoisir;

  const _MecanicienCard({
    required this.mecanicien,
    required this.onChoisir,
  });

  static const List<Color> _avatarColors = [
    Color(0xFF1976D2),
    Color(0xFF00695C),
    Color(0xFF4A148C),
    Color(0xFFE65100),
  ];

  Color get _avatarColor {
    final index = mecanicien.id.hashCode % _avatarColors.length;
    return _avatarColors[index.abs()];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(color: _avatarColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                mecanicien.initiales,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      mecanicien.nom,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: mecanicien.disponible
                            ? const Color(0xFFE8F5E9)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mecanicien.disponible ? 'Disponible' : 'Occupé',
                        style: TextStyle(
                          fontSize: 9,
                          color: mecanicien.disponible
                              ? const Color(0xFF2E7D32)
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  mecanicien.specialite,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(5, (i) {
                      return Icon(
                        i < mecanicien.note.floor()
                            ? Icons.star
                            : i < mecanicien.note
                                ? Icons.star_half
                                : Icons.star_border,
                        color: const Color(0xFFFFB300),
                        size: 14,
                      );
                    }),
                    const SizedBox(width: 4),
                    Text(
                      '${mecanicien.note} (${mecanicien.nombreAvis} avis)',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: mecanicien.disponible ? onChoisir : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Choisir',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(height: 4),
              Text(
                '${mecanicien.distanceKm} km',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
