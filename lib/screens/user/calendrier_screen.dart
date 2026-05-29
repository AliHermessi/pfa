import 'package:flutter/material.dart';
import '../../models/intervention.dart';
import '../../models/vehicle.dart';
import '../../services/intervention_service.dart';
import '../../services/vehicle_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'user_dashboard_screen.dart';
import 'vehicles_screen.dart';
import 'historique_screen.dart';
import 'mecaniciens_screen.dart';
import 'intervention_form_screen.dart';

class CalendrierScreen extends StatefulWidget {
  const CalendrierScreen({super.key});

  @override
  State<CalendrierScreen> createState() => _CalendrierScreenState();
}

class _CalendrierEvent {
  final DateTime date;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _CalendrierEvent({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });
}

class _CalendrierScreenState extends State<CalendrierScreen> {
  int _currentIndex = 3;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

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
      case 4:
        screen = const MecaniciensScreen();
        break;
      default:
        return;
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => screen));
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _selectedDay = null;
    });
  }

  IconData _getInterventionIcon(InterventionTask? task) {
    if (task == null) return Icons.build_outlined;
    switch (task.type) {
      case InterventionType.fluide:
        return Icons.oil_barrel_outlined;
      case InterventionType.piece:
        return Icons.build_outlined;
      case InterventionType.controle:
        return Icons.fact_check_outlined;
      case InterventionType.autre:
        return Icons.more_horiz_rounded;
    }
  }

  List<_CalendrierEvent> _buildEvents(
      List<Vehicle> vehicles, List<Intervention> interventions) {
    List<_CalendrierEvent> events = [];

    // Ajouter le contrôle technique des véhicules
    for (var v in vehicles) {
      if (v.prochainControle.year > 2000) {
        events.add(_CalendrierEvent(
          date: v.prochainControle,
          title: 'Contrôle technique — ${v.nomComplet}',
          subtitle: 'Rappel pour le contrôle technique',
          color: const Color(0xFF1976D2),
          icon: Icons.fact_check_outlined,
        ));
      }
    }

    // Ajouter les interventions
    for (var i in interventions) {
      Color c = i.statut == InterventionStatut.termine
          ? const Color(0xFF2E7D32)
          : i.statut == InterventionStatut.enCours
              ? const Color(0xFF1976D2)
              : i.statut == InterventionStatut.enAttente
                  ? Colors.orange
                  : i.statut == InterventionStatut.annule
                      ? Colors.red
                      : const Color(0xFFE65100);

      final task = i.tasks.isNotEmpty ? i.tasks.first : null;
      final desc = task?.description ?? 'Aucune description';

      events.add(_CalendrierEvent(
        date: i.date,
        title: '${i.typeLabel} — ${i.vehiculeNom}',
        subtitle: desc,
        color: c,
        icon: _getInterventionIcon(task),
      ));
    }

    return events;
  }

  List<_CalendrierEvent> _eventsForDay(
      List<_CalendrierEvent> allEvents, DateTime day) {
    return allEvents
        .where((e) =>
            e.date.year == day.year &&
            e.date.month == day.month &&
            e.date.day == day.day)
        .toList();
  }

  List<_CalendrierEvent> _eventsForSelectedDay(List<_CalendrierEvent> allEvents) {
    if (_selectedDay == null) {
      return allEvents
          .where((e) =>
              e.date.year == _focusedMonth.year &&
              e.date.month == _focusedMonth.month)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }
    return _eventsForDay(allEvents, _selectedDay!)
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday; 

    final List<String> monthNames = [
      '',
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        automaticallyImplyLeading: false,
        title: const Text(
          'Calendrier',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const InterventionFormScreen()),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('RDV',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<List<Vehicle>>(
        stream: VehicleService.vehiclesStream(),
        builder: (context, vehiclesSnapshot) {
          return StreamBuilder<List<Intervention>>(
            stream: InterventionService.interventionsStream(),
            builder: (context, interventionsSnapshot) {
              final vehicles = vehiclesSnapshot.data ?? [];
              final interventions = interventionsSnapshot.data ?? [];
              final allEvents = _buildEvents(vehicles, interventions);
              final filteredEvents = _eventsForSelectedDay(allEvents);

              return Column(
                children: [
                  Container(
                    color: const Color(0xFF1976D2),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left,
                                  color: Colors.white70),
                              onPressed: _prevMonth,
                            ),
                            Text(
                              '${monthNames[_focusedMonth.month]} ${_focusedMonth.year}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right,
                                  color: Colors.white70),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                        Row(
                          children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                              .map((d) => Expanded(
                                    child: Center(
                                      child: Text(d,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500)),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                childAspectRatio: 1.2,
                                mainAxisSpacing: 2,
                                crossAxisSpacing: 2,
                              ),
                              itemCount: (startWeekday - 1) + daysInMonth,
                              itemBuilder: (_, index) {
                                if (index < startWeekday - 1) {
                                  return const SizedBox();
                                }
                                final day = index - (startWeekday - 1) + 1;
                                final date = DateTime(
                                    _focusedMonth.year, _focusedMonth.month, day);
                                final hasEvent = _eventsForDay(allEvents, date).isNotEmpty;
                                final isToday =
                                    date.year == DateTime.now().year &&
                                        date.month == DateTime.now().month &&
                                        date.day == DateTime.now().day;
                                final isSelected = _selectedDay != null &&
                                    _selectedDay!.day == day &&
                                    _selectedDay!.month == _focusedMonth.month &&
                                    _selectedDay!.year == _focusedMonth.year;

                                return GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedDay = isSelected ? null : date;
                                  }),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? Colors.white
                                              : isToday
                                                  ? Colors.white.withOpacity(0.3)
                                                  : Colors.transparent,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$day',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isSelected
                                                  ? const Color(0xFF1976D2)
                                                  : Colors.white,
                                              fontWeight: isToday || isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (hasEvent)
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFFD54F),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: filteredEvents.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_available,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Aucun événement',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                _selectedDay != null
                                    ? 'Événements du ${_selectedDay!.day}/${_selectedDay!.month}'
                                    : 'Événements du mois',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87),
                              ),
                              const SizedBox(height: 10),
                              ...filteredEvents
                                  .map((e) => _EventCard(event: e)),
                            ],
                          ),
                  ),
                ],
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

class _EventCard extends StatelessWidget {
  final _CalendrierEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: event.color, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Icon(event.icon, color: event.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(event.subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
