import 'package:flutter/material.dart';
import '../../models/intervention.dart';
import '../../services/intervention_service.dart';
import '../../services/payment_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'user_dashboard_screen.dart';
import 'vehicles_screen.dart';
import 'calendrier_screen.dart';
import 'mecaniciens_screen.dart';
import 'intervention_form_screen.dart';
import 'payment_screen.dart';
import '../widgets/rating_dialog.dart';
import '../../services/rating_service.dart';
import '../chat_screen.dart';

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  int _currentIndex = 2;
  String _selectedFilter = 'Tous';
  String _selectedYear = 'Toutes';

  final List<String> _filters = [
    'Tous',
    'Vidange',
    'Pneus',
    'Batterie',
    'Freins',
    'Filtre Air',
    'Autre',
  ];
  final List<String> _years = [
    'Toutes',
    '2026',
    '2025',
    '2024',
    '2023',
  ];

  List<Intervention> _applyFilters(List<Intervention> all) {
    return all.where((i) {
      final typeMatch =
          _selectedFilter == 'Tous' || i.typeLabel == _selectedFilter;
      final yearMatch =
          _selectedYear == 'Toutes' || i.date.year.toString() == _selectedYear;
      return typeMatch && yearMatch;
    }).toList();
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

  Future<void> _deleteIntervention(Intervention intervention) async {
    try {
      await InterventionService.deleteIntervention(intervention);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention supprimée')),
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        automaticallyImplyLeading: false,
        title: const Text(
          'Historique',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Intervention>>(
        stream: InterventionService.interventionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }

          final allInterventions = snapshot.data ?? [];
          final filtered = _applyFilters(allInterventions);
          final totalDepense =
              filtered.fold<double>(0, (sum, i) => sum + i.prixEstime);

          return Column(
            children: [
              // ── Total ─────────────────────────────────────────────────
              Container(
                color: const Color(0xFF1976D2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Total: ${totalDepense.toStringAsFixed(0)} DT',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // ── Filtres ───────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 16),
                child: Column(
                  children: [
                    // Filtre par type
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((f) {
                          final isActive = _selectedFilter == f;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedFilter = f),
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
                    const SizedBox(height: 8),
                    // Filtre par année
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _years.map((y) {
                          final isActive = _selectedYear == y;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedYear = y),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF0D1B4B)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive
                                      ? const Color(0xFF0D1B4B)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                y,
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

              // ── Liste des interventions ────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Aucune intervention trouvée',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _HistoriqueCard(
                          intervention: filtered[i],
                          onDelete: () =>
                              _deleteIntervention(filtered[i]),

                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InterventionFormScreen(
                                intervention: filtered[i],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const InterventionFormScreen()),
        ),
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

// ── Historique Card ──────────────────────────────────────────────────────────

class _HistoriqueCard extends StatefulWidget {
  final Intervention intervention;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _HistoriqueCard({
    required this.intervention,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_HistoriqueCard> createState() => _HistoriqueCardState();
}

class _HistoriqueCardState extends State<_HistoriqueCard> {
  bool _isPaymentLoading = false;

  Intervention get intervention => widget.intervention;
  VoidCallback get onDelete => widget.onDelete;
  VoidCallback get onEdit => widget.onEdit;

  IconData get _icon {
    switch (intervention.type) {
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
      case InterventionType.autre:
        return Icons.build_outlined;
    }
  }

  Color get _iconColor {
    switch (intervention.type) {
      case InterventionType.vidange:
        return const Color(0xFFE65100);
      case InterventionType.pneus:
        return const Color(0xFF2E7D32);
      case InterventionType.batterie:
        return const Color(0xFF1976D2);
      case InterventionType.freins:
        return const Color(0xFF6A1B9A);
      default:
        return Colors.grey;
    }
  }

  Color get _iconBg {
    switch (intervention.type) {
      case InterventionType.vidange:
        return const Color(0xFFFFF3E0);
      case InterventionType.pneus:
        return const Color(0xFFE8F5E9);
      case InterventionType.batterie:
        return const Color(0xFFE3F2FD);
      case InterventionType.freins:
        return const Color(0xFFF3E5F5);
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _iconBg, shape: BoxShape.circle),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          const SizedBox(width: 12),
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
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (intervention.mecanicienNom != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '🔧 ${intervention.mecanicienNom}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF1976D2)),
                  ),
                ],
                // Statut badge
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: intervention.statut == InterventionStatut.termine
                        ? const Color(0xFFE8F5E9)
                        : intervention.statut == InterventionStatut.enCours
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    intervention.statutLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color:
                          intervention.statut == InterventionStatut.termine
                              ? const Color(0xFF2E7D32)
                              : intervention.statut ==
                                      InterventionStatut.enCours
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF1976D2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${intervention.prixEstime.toStringAsFixed(0)} DT',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2)),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(intervention: intervention))),
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 20),
                    tooltip: 'Voir la discussion',
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 16, color: Color(0xFF1976D2)),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ],
                      )),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Supprimer',
                              style: TextStyle(color: Colors.red)),
                        ],
                      )),
                ],
              ),
              ],
            ),
            if (intervention.statut == InterventionStatut.termine &&
                  intervention.mecanicienId != null) ...[
                const SizedBox(height: 8),
                // ── Bouton Payer / Badge Payé ──────────────────────────
                if (!intervention.estPaye)
                  _isPaymentLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _startPayment(context),
                          icon: const Icon(Icons.payment, size: 14),
                          label: const Text('Payer',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF43A047),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(20)),
                          ),
                        )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF43A047), width: 0.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: Color(0xFF43A047), size: 13),
                        SizedBox(width: 4),
                        Text('Payé',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF43A047))),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                // ── Bouton Noter ───────────────────────────────────────
                if (intervention.noteClient == null)
                  ElevatedButton(
                    onPressed: () async {
                      final note = await showDialog<int>(
                        context: context,
                        builder: (ctx) => RatingDialog(
                            mecanicienNom: intervention.mecanicienNom ?? 'le mécanicien'),
                      );
                      if (note != null) {
                        try {
                          await RatingService.submitRating(
                              intervention.mecanicienId!,
                              intervention.id,
                              intervention.userId,
                              note);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Merci pour votre évaluation !')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur: $e')));
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('⭐ Noter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFB300), size: 14),
                      const SizedBox(width: 4),
                      Text('${intervention.noteClient}/5', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Lancer le flux de paiement Flouci ─────────────────────────────────────
  Future<void> _startPayment(BuildContext context) async {
    setState(() => _isPaymentLoading = true);

    try {
      final result = await PaymentService.generatePayment(
        amountInDT: intervention.prixEstime,
        trackingId: intervention.id,
      );

      final paymentUrl = result['link']!;
      final paymentId = result['paymentId']!;

      if (!context.mounted) return;

      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            paymentUrl: paymentUrl,
            paymentId: paymentId,
            intervention: intervention,
          ),
        ),
      );

      if (success == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Paiement effectué avec succès !'),
              ],
            ),
            backgroundColor: Color(0xFF43A047),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de paiement : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaymentLoading = false);
    }
  }
}
