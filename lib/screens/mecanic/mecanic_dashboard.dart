import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/intervention.dart';
import '../../services/intervention_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../login_screen.dart';
import '../chat_screen.dart';
import '../user/notifications_screen.dart';

class MechanicDashboard extends StatefulWidget {
  const MechanicDashboard({super.key});

  @override
  State<MechanicDashboard> createState() => _MechanicDashboardState();
}

class _MechanicDashboardState extends State<MechanicDashboard> {
  int _currentIndex = 0;
  String _activeFilter = 'Tous';
  bool _disponible = true; // statut local (mis à jour depuis Firebase)
  bool _gpsActive = false;  // tracking GPS actif

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late final DatabaseReference _mecaRef;
  late final Stream<List<Intervention>> _interventionsStream;

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    return 'Mécanicien';
  }

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _mecaRef = FirebaseDatabase.instance.ref('mecaniciens/$_uid');
      _interventionsStream = InterventionService.mecanicInterventionsStream(_uid!);
      
      // Lire le statut initial depuis Firebase
      _mecaRef.child('disponible').onValue.listen((event) {
        if (mounted) {
          setState(() {
            _disponible = (event.snapshot.value as bool?) ?? true;
          });
        }
      });
      // Démarrer le tracking GPS
      _startGps();
    } else {
      // Fallback empty stream
      _interventionsStream = const Stream.empty();
    }
  }

  Future<void> _startGps() async {
    final ok = await LocationService.startTracking(_uid!);
    if (mounted) setState(() => _gpsActive = ok);
  }

  @override
  void dispose() {
    if (_uid != null) LocationService.stopTracking(_uid!);
    super.dispose();
  }

  /// Toggle manuel — ignoré si une intervention est en cours
  Future<void> _toggleDisponibilite(List<Intervention> all) async {
    final hasEnCours = all.any((i) => i.statut == InterventionStatut.enCours);
    if (hasEnCours) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Vous avez une intervention en cours — statut automatiquement Occupé'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final newVal = !_disponible;
    await _mecaRef.update({'disponible': newVal});
    // setState se fera via le listener onValue
  }

  /// Met à jour Firebase automatiquement selon les interventions en cours
  Future<void> _syncDisponibiliteAuto(List<Intervention> all) async {
    final hasEnCours = all.any((i) => i.statut == InterventionStatut.enCours);
    // Si en cours → forcer Occupé dans Firebase
    if (hasEnCours && _disponible) {
      await _mecaRef.update({'disponible': false});
    }
    // Si plus rien en cours ET était forcé Occupé par auto → repasser Disponible
    // (seulement si c'était auto, pas si le mécanicien l'a mis manuellement)
    // On ne remet pas à true automatiquement pour laisser le contrôle au mécanicien
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const LoginScreen();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _currentIndex == 0
              ? 'Dashboard'
              : (_currentIndex == 1 ? 'Mes Rendez-vous' : 'Historique'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // ── Indicateur GPS ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: _gpsActive ? 'Position GPS active' : 'GPS inactif',
              child: Icon(
                _gpsActive ? Icons.location_on : Icons.location_off,
                color: _gpsActive ? Colors.greenAccent : Colors.white38,
                size: 20,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              // Arrêter le GPS avant de déconnecter
              if (_uid != null) await LocationService.stopTracking(_uid!);
              await AuthService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Intervention>>(
        stream: _interventionsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final interventions = snapshot.data ?? [];

          // Sync auto disponibilité
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncDisponibiliteAuto(interventions);
          });

          switch (_currentIndex) {
            case 0:
              return _buildHomeTab(interventions);
            case 1:
              return _buildAppointmentsTab(interventions);
            case 2:
              return _buildHistoryTab(interventions);
            default:
              return Container();
          }
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF1976D2),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded), label: 'Accueil'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_rounded), label: 'Rendez-vous'),
            BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded), label: 'Historique'),
          ],
        ),
      ),
    );
  }

  // ─── ONGLET 1 : ACCUEIL ───────────────────────────────────────────────────
  Widget _buildHomeTab(List<Intervention> all) {
    final today = DateTime.now();
    final rdvToday = all
        .where((i) =>
            i.date.day == today.day &&
            i.date.month == today.month &&
            i.date.year == today.year)
        .toList();
    final finished =
        all.where((i) => i.statut == InterventionStatut.termine).toList();
    final inProgress =
        all.where((i) => i.statut == InterventionStatut.enCours).toList();
    final urgent =
        all.where((i) => i.statut == InterventionStatut.enAttente).toList();

    // Statut effectif : occupé si intervention en cours, sinon valeur Firebase
    final bool isOccupe = inProgress.isNotEmpty || !_disponible;
    final bool autoOccupe = inProgress.isNotEmpty; // occupé par auto

    double revenueToday = 0;
    for (var i in finished) {
      if (i.date.day == today.day &&
          i.date.month == today.month &&
          i.date.year == today.year) {
        revenueToday += i.prixEstime;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header avec toggle disponibilité ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bonjour, $_userName 👋',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('Voici votre journée',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              // ── Badge disponibilité + toggle ───────────────────────────────
              GestureDetector(
                onTap: () => _toggleDisponibilite(all),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOccupe ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOccupe
                          ? Colors.red.shade200
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dot animé
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOccupe ? Colors.red : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOccupe ? 'Occupé' : 'Disponible',
                        style: TextStyle(
                          color: isOccupe ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (!autoOccupe) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: isOccupe ? Colors.red : Colors.green,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (autoOccupe)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.info_outline,
                      size: 12, color: Colors.orange.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Statut auto — intervention en cours',
                    style:
                        TextStyle(fontSize: 10, color: Colors.orange.shade600),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // ── Alertes ────────────────────────────────────────────────────────
          if (urgent.isNotEmpty)
            _AlertBanner(
              color: Colors.red,
              icon: Icons.warning_amber_rounded,
              title: 'Rendez-vous urgent — ${_formatTime(urgent.first.date)}',
              subtitle:
                  '${urgent.first.vehiculeNom} · ${urgent.first.typeLabel}',
            ),

          if (inProgress.isNotEmpty && urgent.isEmpty)
            _AlertBanner(
              color: Colors.orange,
              icon: Icons.build_circle_outlined,
              title: 'Intervention en cours',
              subtitle:
                  '${inProgress.first.vehiculeNom} · ${inProgress.first.typeLabel}',
            ),

          const SizedBox(height: 4),

          // ── Grille de stats (responsive) ───────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              // Sur mobile : 2 colonnes, sur web/tablet : 4 colonnes
              final crossCount = constraints.maxWidth > 600 ? 4 : 2;
              final ratio = constraints.maxWidth > 600 ? 1.6 : 1.3;
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: ratio,
                children: [
                  _StatCard(
                      title: "RDV aujourd'hui",
                      value: '${rdvToday.length}',
                      icon: Icons.calendar_today,
                      color: Colors.blue),
                  _StatCard(
                      title: 'Terminés',
                      value: '${finished.length}',
                      icon: Icons.check_circle_outline,
                      color: Colors.green),
                  _StatCard(
                      title: 'En cours',
                      value: '${inProgress.length}',
                      icon: Icons.build_outlined,
                      color: Colors.orange),
                  _StatCard(
                      title: 'Revenus du jour',
                      value: '${revenueToday.toInt()} DT',
                      icon: Icons.monetization_on_outlined,
                      color: Colors.purple),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          const Text('Interventions du mois',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildMonthlyStats(all),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMonthlyStats(List<Intervention> all) {
    final now = DateTime.now();
    final thisMonth = all
        .where((i) => i.date.month == now.month && i.date.year == now.year)
        .toList();

    Map<String, int> counts = {};
    for (var i in thisMonth) {
      counts[i.typeLabel] = (counts[i.typeLabel] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text('Aucune intervention ce mois',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final maxVal = counts.values.fold(0, (a, b) => a > b ? a : b);

    // Couleurs par type
    final Map<String, Color> typeColors = {
      'Vidange': Colors.blue,
      'Pneus': Colors.green,
      'Freins': Colors.orange,
      'Batterie': Colors.purple,
      'Filtre Air': Colors.teal,
      'Autre': Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Types d\'intervention ce mois',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          ...counts.entries.map((e) {
            final color = typeColors[e.key] ?? Colors.blue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(e.key, style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    flex: 6,
                    child: LinearProgressIndicator(
                      value: maxVal > 0 ? e.value / maxVal : 0,
                      backgroundColor: Colors.grey.shade100,
                      color: color,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${e.value}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── ONGLET 2 : RENDEZ-VOUS ────────────────────────────────────────────────
  Widget _buildAppointmentsTab(List<Intervention> all) {
    final filteredList = all.where((i) {
      if (_activeFilter == 'Tous') {
        return i.statut != InterventionStatut.termine &&
            i.statut != InterventionStatut.annule;
      }
      if (_activeFilter == 'Planifié')
        return i.statut == InterventionStatut.planifie;
      if (_activeFilter == 'En cours')
        return i.statut == InterventionStatut.enCours;
      if (_activeFilter == 'Urgent')
        return i.statut == InterventionStatut.enAttente;
      return true;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Tous'),
                _buildFilterChip('Planifié'),
                _buildFilterChip('En cours'),
                _buildFilterChip('Urgent'),
              ],
            ),
          ),
        ),
        Expanded(
          child: filteredList.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Aucun rendez-vous trouvé',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) =>
                      _AppointmentCard(intervention: filteredList[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    bool isActive = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── ONGLET 3 : HISTORIQUE ─────────────────────────────────────────────────
  Widget _buildHistoryTab(List<Intervention> all) {
    final history = all
        .where((i) => i.statut == InterventionStatut.termine)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    double total = history.fold(0, (sum, i) => sum + i.prixEstime);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total des prestations',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Text('${total.toInt()} DT',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1976D2))),
            ],
          ),
        ),
        Expanded(
          child: history.isEmpty
              ? const Center(
                  child: Text('Aucun historique',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: history.length,
                  itemBuilder: (context, index) =>
                      _HistoryCard(intervention: history[index]),
                ),
        ),
      ],
    );
  }
}

// ─── SOUS-WIDGETS ─────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title, subtitle;
  const _AlertBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: color)),
                Text(subtitle,
                    style:
                        TextStyle(color: color.withOpacity(0.8), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Intervention intervention;
  const _AppointmentCard({required this.intervention});

  String _formatDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')} · ${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: intervention.statut == InterventionStatut.enAttente
              ? Colors.red.shade100
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Text(
                  intervention.vehiculeNom.isNotEmpty
                      ? intervention.vehiculeNom.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(intervention.vehiculeNom,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '${intervention.typeLabel} · ${_formatDateTime(intervention.date)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (intervention.description.isNotEmpty)
                      Text(
                        intervention.description,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _StatusBadge(statut: intervention.statut),
            ],
          ),
          if (intervention.statut == InterventionStatut.enAttente) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        InterventionService.cancelIntervention(intervention),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Refuser'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        InterventionService.acceptIntervention(intervention),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accepter'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
          if (intervention.statut == InterventionStatut.planifie) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        InterventionService.startIntervention(intervention),
                    icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                    label: const Text('Commencer l\'intervention', style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(intervention: intervention))),
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                    tooltip: 'Discuter avec le client',
                  ),
                ),
              ],
            ),
          ],
          if (intervention.statut == InterventionStatut.enCours) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final finalPrice = await showDialog<double>(
                        context: context,
                        builder: (ctx) {
                          final ctrl = TextEditingController(text: intervention.prixEstime > 0 ? intervention.prixEstime.toStringAsFixed(0) : '');
                          return AlertDialog(
                            title: const Text("Finaliser l'intervention"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Veuillez saisir le prix final (DT) de la prestation :"),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: "Ex: 120",
                                    suffixText: "DT",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 0.0),
                                child: const Text("Valider"),
                              ),
                            ],
                          );
                        },
                      );
                      if (finalPrice != null) {
                        await InterventionService.completeIntervention(intervention, finalPrice: finalPrice);
                      }
                    },
                    icon: const Icon(Icons.done_all, size: 16, color: Colors.white),
                    label: const Text('Terminer l\'intervention', style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(intervention: intervention))),
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                    tooltip: 'Discuter avec le client',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Intervention intervention;
  const _HistoryCard({required this.intervention});

  IconData _getIcon(InterventionType type) {
    switch (type) {
      case InterventionType.vidange:
        return Icons.oil_barrel_outlined;
      case InterventionType.pneus:
        return Icons.tire_repair_outlined;
      case InterventionType.batterie:
        return Icons.battery_charging_full_outlined;
      case InterventionType.freins:
        return Icons.disc_full_outlined;
      case InterventionType.filtreAir:
        return Icons.air_outlined;
      default:
        return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(_getIcon(intervention.type), color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(intervention.typeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${intervention.vehiculeNom} · ${intervention.date.day}/${intervention.date.month}/${intervention.date.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${intervention.prixEstime.toInt()} DT',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                    fontSize: 15),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(intervention: intervention))),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 16),
                    SizedBox(width: 4),
                    Text('Discussion', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final InterventionStatut statut;
  const _StatusBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.blue.shade50;
    Color text = Colors.blue;
    String label = 'Planifié';

    if (statut == InterventionStatut.enCours) {
      bg = Colors.orange.shade50;
      text = Colors.orange;
      label = 'En cours';
    } else if (statut == InterventionStatut.termine) {
      bg = Colors.green.shade50;
      text = Colors.green;
      label = 'Terminé';
    } else if (statut == InterventionStatut.enAttente) {
      bg = Colors.red.shade50;
      text = Colors.red;
      label = 'Urgent';
    } else if (statut == InterventionStatut.annule) {
      bg = Colors.grey.shade100;
      text = Colors.grey;
      label = 'Annulé';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: text, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
