import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/intervention.dart';
import '../../models/mecanicien.dart';
import '../../models/vehicle.dart';
import '../../services/intervention_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/vehicle_service.dart';
import '../login_screen.dart';
import '../user/notifications_screen.dart';
import '../user/profile_screen.dart';
import 'complete_intervention_screen.dart';

enum ChartDataType { revenue, count }
enum ChartInterval { day, week, month, threeMonths, year }

class MechanicDashboard extends StatefulWidget {
  const MechanicDashboard({super.key});

  @override
  State<MechanicDashboard> createState() => _MechanicDashboardState();
}

class _MechanicDashboardState extends State<MechanicDashboard> {
  int _currentIndex = 0;
  String _activeFilter = 'Tous';
  bool _disponible = true; 
  bool _checkedProfile = false;
  
  // Graph filters
  ChartDataType _chartDataType = ChartDataType.revenue;
  ChartInterval _chartInterval = ChartInterval.week;

  // Calendar state
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  bool _rememberAcceptChoice = false;

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
    final uid = _uid;
    if (uid != null) {
      _mecaRef = FirebaseDatabase.instance.ref('mecaniciens/$uid');
      _interventionsStream = InterventionService.mecanicInterventionsStream(uid);
      
      _mecaRef.child('disponible').onValue.listen((event) {
        if (mounted) {
          setState(() {
            _disponible = (event.snapshot.value as bool?) ?? true;
          });
        }
      });
      _startGps();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkProfileCompletion();
      });
    } else {
      _interventionsStream = const Stream.empty();
    }
  }

  void _checkProfileCompletion() async {
    if (_uid == null || _checkedProfile) return;

    final snapshot = await _mecaRef.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      final meca = Mecanicien.fromMap(_uid!, data);
      
      // Check for empty fields
      if (meca.nom.isEmpty || meca.telephone.isEmpty || meca.nomGarage.isEmpty || meca.adresseGarage.isEmpty) {
        _showIncompleteProfileDialog();
      }
    }
    _checkedProfile = true;
  }

  void _showIncompleteProfileDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil incomplet'),
        content: const Text('Certaines informations de votre garage ne sont pas encore renseignées. Souhaitez-vous les completer maintenant ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: const Text('Completer'),
          ),
        ],
      ),
    );
  }

  Future<void> _startGps() async {
    final uid = _uid;
    if (uid == null) return;
    await LocationService.startTracking(uid);
  }

  @override
  void dispose() {
    final uid = _uid;
    if (uid != null) LocationService.stopTracking(uid);
    super.dispose();
  }

  Future<void> _toggleDisponibilite(List<Intervention> all) async {
    final hasEnCours = all.any((i) => i.statut == InterventionStatut.enCours);
    if (hasEnCours) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez une intervention en cours — statut Occupé')),
      );
      return;
    }
    await _mecaRef.update({'disponible': !_disponible});
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const LoginScreen();
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _currentIndex == 0 ? 'Vue d\'ensemble' : (_currentIndex == 1 ? 'Rendez-vous' : 'Historique'),
          style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFF1F5F9),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, color: Color(0xFF64748B), size: 18) : null,
            ),
            tooltip: 'Mon Profil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await AuthService.logout();
              navigator.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Intervention>>(
        stream: _interventionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final interventions = snapshot.data ?? [];

          switch (_currentIndex) {
            case 0: return _buildHomeTab(interventions);
            case 1: return _buildAppointmentsTab(interventions);
            case 2: return _buildHistoryTab(interventions);
            default: return Container();
          }
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: const Color(0xFF94A3B8),
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Tableau'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Rendez-vous'),
          BottomNavigationBarItem(icon: Icon(Icons.history_edu_rounded), label: 'Historique'),
        ],
      ),
    );
  }

  // ── HOME TAB ─────────────────────────────────────────────────────────────
  Widget _buildHomeTab(List<Intervention> all) {
    final finished = all.where((i) => i.statut == InterventionStatut.termine).toList();
    final inProgress = all.where((i) => i.statut == InterventionStatut.enCours).toList();
    final pending = all.where((i) => i.statut == InterventionStatut.enAttente).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(all),
          const SizedBox(height: 24),
          _buildStatGrid(finished, inProgress, pending),
          const SizedBox(height: 32),
          _buildChartSection(all),
          const SizedBox(height: 32),
          const Text('Activités Récentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          if (all.isEmpty) _buildEmptyState() else ...all.take(3).map((i) => _buildInterventionLine(i)),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(List<Intervention> all) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenue, $_userName', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const Text('Gérez vos interventions du jour', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
        GestureDetector(
          onTap: () => _toggleDisponibilite(all),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _disponible ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: (_disponible ? Colors.green : Colors.red).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.white, size: 8),
                const SizedBox(width: 8),
                Text(_disponible ? 'Disponible' : 'Occupé', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid(List<Intervention> finished, List<Intervention> inProgress, List<Intervention> pending) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _PremiumStatCard(title: 'Terminés', value: '${finished.length}', icon: Icons.check_circle_rounded, colors: const [Color(0xFF10B981), Color(0xFF059669)]),
        _PremiumStatCard(title: 'En cours', value: '${inProgress.length}', icon: Icons.pending_actions_rounded, colors: const [Color(0xFF3B82F6), Color(0xFF2563EB)]),
        _PremiumStatCard(title: 'Demandes', value: '${pending.length}', icon: Icons.notification_important_rounded, colors: const [Color(0xFFF59E0B), Color(0xFFD97706)]),
        const _PremiumStatCard(title: 'Avis Client', value: '4.8', icon: Icons.star_rounded, colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
      ],
    );
  }

  Widget _buildChartSection(List<Intervention> interventions) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Analytiques', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              _buildChartTypeSelector(),
            ],
          ),
          const SizedBox(height: 16),
          _buildIntervalSelector(),
          const SizedBox(height: 24),
          SizedBox(height: 220, child: _buildGraph(interventions)),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _TypeBtn(ChartDataType.revenue, 'Revenu', _chartDataType == ChartDataType.revenue, (t) => setState(() => _chartDataType = t)),
          _TypeBtn(ChartDataType.count, 'RDV', _chartDataType == ChartDataType.count, (t) => setState(() => _chartDataType = t)),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector() {
    final intervals = {
      ChartInterval.day: '1J',
      ChartInterval.week: '1S',
      ChartInterval.month: '1M',
      ChartInterval.threeMonths: '3M',
      ChartInterval.year: '1A',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: intervals.entries.map((e) {
        final isSelected = _chartInterval == e.key;
        return GestureDetector(
          onTap: () => setState(() => _chartInterval = e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
            child: Text(e.value, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGraph(List<Intervention> interventions) {
    final data = _getChartData(interventions);
    if (data.isEmpty) return const Center(child: Text('Pas de données pour cette période'));

    double maxY = data.map((e) => e.y).fold(0, (prev, curr) => curr > prev ? curr : prev);
    if (maxY == 0) maxY = 10;

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
            if (v.toInt() % (data.length / 5).ceil() == 0 && v < data.length) {
              return Text(data[v.toInt()].label, style: const TextStyle(fontSize: 9, color: Colors.grey));
            }
            return const Text('');
          })),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i].y)),
            isCurved: true,
            color: const Color(0xFF3B82F6),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF3B82F6).withOpacity(0.1)),
          ),
        ],
        minY: 0,
        maxY: maxY * 1.2,
      ),
    );
  }

  List<_ChartPoint> _getChartData(List<Intervention> all) {
    final now = DateTime.now();
    DateTime start;
    int steps;
    Duration stepDuration;

    switch (_chartInterval) {
      case ChartInterval.day: 
        start = DateTime(now.year, now.month, now.day); steps = 24; stepDuration = const Duration(hours: 1); break;
      case ChartInterval.week: 
        start = now.subtract(const Duration(days: 6)); steps = 7; stepDuration = const Duration(days: 1); break;
      case ChartInterval.month: 
        start = now.subtract(const Duration(days: 29)); steps = 30; stepDuration = const Duration(days: 1); break;
      case ChartInterval.threeMonths: 
        start = now.subtract(const Duration(days: 90)); steps = 13; stepDuration = const Duration(days: 7); break;
      case ChartInterval.year: 
        start = DateTime(now.year, now.month, 1).subtract(const Duration(days: 330)); steps = 12; stepDuration = const Duration(days: 30); break;
    }

    List<_ChartPoint> points = [];
    for (int i = 0; i < steps; i++) {
      final stepStart = start.add(stepDuration * i);
      final stepEnd = stepStart.add(stepDuration);
      
      final inPeriod = all.where((inter) {
        if (inter.statut != InterventionStatut.termine) return false;
        return inter.date.isAfter(stepStart) && inter.date.isBefore(stepEnd);
      });

      double val = _chartDataType == ChartDataType.revenue 
          ? inPeriod.fold(0.0, (sum, item) => sum + item.prixEstime)
          : inPeriod.length.toDouble();

      String label = '';
      if (_chartInterval == ChartInterval.day) {
        label = '${stepStart.hour}h';
      } else if (_chartInterval == ChartInterval.year) {
        label = DateFormat.MMM('fr_FR').format(stepStart);
      } else {
        label = '${stepStart.day}/${stepStart.month}';
      }

      points.add(_ChartPoint(label, val));
    }
    return points;
  }

  Widget _buildInterventionLine(Intervention i) {
    return GestureDetector(
      onTap: () => _showInterventionDetails(i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.all(Radius.circular(12))), child: const Icon(Icons.build_rounded, color: Color(0xFF3B82F6), size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.vehiculeNom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${DateFormat.Hm().format(i.date)} · ${i.typeLabel}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${i.prixEstime.toInt()} DT', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              _buildMiniStatus(i.statut),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatus(InterventionStatut s) {
    Color c = Colors.grey;
    if (s == InterventionStatut.enCours) c = Colors.blue;
    if (s == InterventionStatut.termine) c = Colors.green;
    if (s == InterventionStatut.enAttente) c = Colors.orange;
    return Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }

  Widget _buildEmptyState() => const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucune activité', style: TextStyle(color: Colors.grey))));

  // ── APPOINTMENTS TAB (CALENDAR) ──────────────────────────────────────────
  Widget _buildAppointmentsTab(List<Intervention> all) {
    final filteredByDay = all.where((i) {
      if (_selectedDay == null) return true;
      return i.date.year == _selectedDay!.year && i.date.month == _selectedDay!.month && i.date.day == _selectedDay!.day;
    }).toList();

    final filteredByStatus = filteredByDay.where((i) {
      if (_activeFilter == 'Tous') return i.statut != InterventionStatut.annule;
      if (_activeFilter == 'Planifié') return i.statut == InterventionStatut.planifie;
      if (_activeFilter == 'En cours') return i.statut == InterventionStatut.enCours;
      if (_activeFilter == 'Urgent') return i.statut == InterventionStatut.enAttente;
      if (_activeFilter == 'Terminé') return i.statut == InterventionStatut.termine;
      return true;
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      children: [
        _buildCalendarHeader(),
        _buildFilterBar(),
        Expanded(
          child: filteredByStatus.isEmpty ? _buildEmptyState() : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredByStatus.length,
            itemBuilder: (context, index) => _AppointmentCard(
              intervention: filteredByStatus[index], 
              onTap: () => _showInterventionDetails(filteredByStatus[index]),
              onAccept: () => _handleAccept(filteredByStatus[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstDayWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMMM yyyy', 'fr_FR').format(_focusedMonth), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1))),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1))),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 10, color: Colors.grey))))).toList()),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.2),
            itemCount: (firstDayWeekday - 1) + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstDayWeekday - 1) return const SizedBox();
              final day = index - (firstDayWeekday - 1) + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final isSelected = _selectedDay != null && _selectedDay!.day == day && _selectedDay!.month == _focusedMonth.month && _selectedDay!.year == _focusedMonth.year;
              final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;

              return GestureDetector(
                onTap: () => setState(() => _selectedDay = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF3B82F6) : (isToday ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text('$day', style: TextStyle(fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : (isToday ? const Color(0xFF3B82F6) : Colors.black87)))),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: ['Tous', 'Planifié', 'En cours', 'Urgent', 'Terminé'].map((f) => _buildFilterChip(f)).toList()),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isActive = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  // ── ACTIONS ──────────────────────────────────────────────────────────────
  void _showInterventionDetails(Intervention i) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InterventionDetailPanel(
        intervention: i,
        onAccept: () { Navigator.pop(context); _handleAccept(i); },
        onStart: () { Navigator.pop(context); InterventionService.startIntervention(i); },
        onFinish: () { 
          Navigator.pop(context); 
          Navigator.push(context, MaterialPageRoute(builder: (_) => CompleteInterventionScreen(intervention: i)));
        },
        onCancel: () { Navigator.pop(context); InterventionService.cancelIntervention(i); },
      ),
    );
  }

  Future<void> _handleAccept(Intervention i) async {
    if (_rememberAcceptChoice) {
      await InterventionService.acceptIntervention(i);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Confirmer l\'acceptation', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Souhaitez-vous accepter cette intervention ? Nous vous conseillons d\'appeler le client pour confirmer les détails.'),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _rememberAcceptChoice,
                onChanged: (v) => setDialogState(() => _rememberAcceptChoice = v!),
                title: const Text('Se souvenir de mon choix', style: TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Accepter'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await InterventionService.acceptIntervention(i);
    }
  }

  Widget _buildHistoryTab(List<Intervention> all) {
    final history = all.where((i) => i.statut == InterventionStatut.termine).toList()..sort((a, b) => b.date.compareTo(a.date));
    double total = history.fold(0.0, (sum, i) => sum + i.prixEstime);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
          child: Row(children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gains cumulés', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
              Text('Historique complet', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
            ]),
            const Spacer(),
            Text('${total.toInt()} DT', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ]),
        ),
        Expanded(child: history.isEmpty ? _buildEmptyState() : ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: history.length,
          itemBuilder: (context, index) => _buildInterventionLine(history[index]),
        )),
      ],
    );
  }
}

// ── WIDGETS INTERNES ──────────────────────────────────────────────────────────

class _PremiumStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final List<Color> colors;
  const _PremiumStatCard({required this.title, required this.value, required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Intervention intervention;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  const _AppointmentCard({required this.intervention, required this.onTap, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: const Color(0xFFF1F5F9), child: Text(intervention.vehiculeNom.isNotEmpty ? intervention.vehiculeNom.substring(0, 1) : '?', style: const TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(intervention.vehiculeNom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${DateFormat.Hm().format(intervention.date)} · ${intervention.typeLabel}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ])),
                  _StatusBadge(statut: intervention.statut),
                ],
              ),
            ),
            if (intervention.statut == InterventionStatut.enAttente)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  Expanded(child: ElevatedButton(onPressed: onAccept, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Accepter'))),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final InterventionStatut statut;
  const _StatusBadge({required this.statut});
  @override
  Widget build(BuildContext context) {
    Color c = Colors.blue;
    String l = 'Prévu';
    if (statut == InterventionStatut.enCours) { c = Colors.orange; l = 'En cours'; }
    else if (statut == InterventionStatut.termine) { c = Colors.green; l = 'Terminé'; }
    else if (statut == InterventionStatut.enAttente) { c = Colors.red; l = 'Urgent'; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(l, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)));
  }
}

class _TypeBtn extends StatelessWidget {
  final ChartDataType type;
  final String label;
  final bool active;
  final Function(ChartDataType) onTap;
  const _TypeBtn(this.type, this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : null),
        child: Text(label, style: TextStyle(color: active ? const Color(0xFF1E293B) : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }
}

class _ChartPoint {
  final String label;
  final double y;
  _ChartPoint(this.label, this.y);
}

class _InterventionDetailPanel extends StatelessWidget {
  final Intervention intervention;
  final VoidCallback onAccept, onStart, onFinish, onCancel;
  const _InterventionDetailPanel({required this.intervention, required this.onAccept, required this.onStart, required this.onFinish, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Détails de la mission', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _detailRow(Icons.directions_car, 'Véhicule', intervention.vehiculeNom),
            
            // Fetch and show permanent vehicle photos
            FutureBuilder<Vehicle?>(
              future: VehicleService.getVehicle(intervention.userId, intervention.vehiculeId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data?.imageUrls != null && snapshot.data!.imageUrls.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text('Photos du véhicule (Général) :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: snapshot.data!.imageUrls.length,
                          itemBuilder: (context, idx) => GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(child: Image.network(snapshot.data!.imageUrls[idx])),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(snapshot.data!.imageUrls[idx], width: 100, height: 100, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox();
              }
            ),

            const SizedBox(height: 12),
            _detailRow(Icons.build, 'Type', intervention.typeLabel),
            _detailRow(Icons.access_time, 'Heure', DateFormat.Hm().format(intervention.date)),
            _detailRow(Icons.person, 'Client ID', intervention.userId),
            if (intervention.tasks.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Tâches à effectuer :', style: TextStyle(fontWeight: FontWeight.bold)),
              ...intervention.tasks.map((t) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• ${t.label}', style: const TextStyle(fontSize: 13, color: Colors.grey)))),
            ],
            if (intervention.imageUrls != null && intervention.imageUrls!.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Photos envoyées pour cette mission :', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: intervention.imageUrls!.length,
                  itemBuilder: (context, idx) => GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(child: Image.network(intervention.imageUrls![idx])),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(intervention.imageUrls![idx], width: 120, height: 120, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (intervention.statut == InterventionStatut.enAttente)
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: onCancel, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Refuser'))),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(onPressed: onAccept, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Accepter'))),
              ])
            else if (intervention.statut == InterventionStatut.planifie)
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onStart, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Commencer la mission')))
            else if (intervention.statut == InterventionStatut.enCours)
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onFinish, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Terminer l\'intervention')))
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
      Icon(icon, size: 20, color: Colors.blue),
      const SizedBox(width: 12),
      Text('$label : ', style: const TextStyle(color: Colors.grey)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]));
  }
}
