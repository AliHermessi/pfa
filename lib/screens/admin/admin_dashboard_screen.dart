import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/mecanicien.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../services/export_service.dart';
import '../login_screen.dart';
import 'user_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final _mecaRef = FirebaseDatabase.instance.ref('mecaniciens');
  
  late final Stream<DatabaseEvent> _mecaStream;
  late final Stream<DatabaseEvent> _interventionsStream;
  
  Future<List<double>>? _revenueFuture;
  Future<List<int>>? _interventionsCountFuture;
  final int _currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _mecaStream = _mecaRef.onValue;
    _interventionsStream = FirebaseDatabase.instance.ref('interventions').onValue;
    
    _refreshFutures();
    
    // Refresh chart data only when interventions change
    _interventionsStream.listen((event) {
      if (mounted) {
        _refreshFutures();
      }
    });
  }

  void _refreshFutures() {
    setState(() {
      _revenueFuture = AdminService.getMonthlyRevenue(_currentYear);
      _interventionsCountFuture = AdminService.getMonthlyInterventionsCount(_currentYear);
    });
  }

  Future<void> _exportData(bool isExcel) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 16),
            Text("Génération de l'export en cours..."),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
    
    final data = await AdminService.getAllInterventionsForExport();
    String? path;
    
    if (isExcel) {
      path = await ExportService.exportToExcel(data);
    } else {
      path = await ExportService.exportToPdf(data);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Fichier sauvegardé avec succès !"), 
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.green.shade600,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Erreur lors de l'exportation"), 
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Dashboard';
    if (_currentIndex == 1) title = 'Utilisateurs';
    if (_currentIndex == 2) title = 'Mécaniciens';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), // Soft modern background
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1E293B), 
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (_currentIndex == 0) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.picture_as_pdf, color: Colors.red.shade600, size: 20),
                tooltip: 'Exporter en PDF',
                onPressed: () => _exportData(false),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.table_chart, color: Colors.green.shade600, size: 20),
                tooltip: 'Exporter en Excel',
                onPressed: () => _exportData(true),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF64748B), size: 20),
              onPressed: () async {
                await AuthService.logout();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(),
          const UserManagementScreen(),
          _buildMecaniciensList(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: const Color(0xFF3B82F6),
            unselectedItemColor: const Color(0xFF94A3B8),
            backgroundColor: Colors.white,
            elevation: 0,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.space_dashboard_rounded)),
                activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.space_dashboard_rounded, size: 28)),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.people_rounded)),
                activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.people_rounded, size: 28)),
                label: 'Utilisateurs',
              ),
              BottomNavigationBarItem(
                icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.engineering_rounded)),
                activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.engineering_rounded, size: 28)),
                label: 'Mécaniciens',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── DASHBOARD AVEC GRAPHIQUES ─────────────────────────────────────────────
  Widget _buildDashboard() {
    final currentYear = _currentYear;
    return StreamBuilder<DatabaseEvent>(
      stream: _mecaStream,
      builder: (context, mecaSnapshot) {
        return StreamBuilder<DatabaseEvent>(
          stream: _interventionsStream,
          builder: (context, interSnapshot) {
            int totalMeca = 0, totalInterventions = 0, pending = 0;

            if (mecaSnapshot.hasData && mecaSnapshot.data!.snapshot.value != null) {
              final data = mecaSnapshot.data!.snapshot.value;
              if (data is Map) {
                data.forEach((_, v) {
                  if (v is Map) {
                    totalMeca++;
                    if (v['isApproved'] == false) pending++;
                  }
                });
              }
            }

            if (interSnapshot.hasData && interSnapshot.data!.snapshot.value != null) {
              final data = interSnapshot.data!.snapshot.value;
              if (data is Map) {
                data.forEach((_, v) {
                  if (v is Map) totalInterventions += v.length;
                });
              }
            }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vue Globale', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))
              ),
              const SizedBox(height: 16),
              
              if (pending > 0)
                GestureDetector(
                  onTap: () => setState(() => _currentIndex = 2),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFF97316).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${pending} mécanicien(s) en attente', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Appuyez pour examiner les profils', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9))),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
                
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 600;
                  return Flex(
                    direction: isDesktop ? Axis.horizontal : Axis.vertical,
                    children: [
                      Expanded(
                        flex: isDesktop ? 1 : 0,
                        child: _PremiumStatCard(
                          title: 'Mécaniciens Actifs', 
                          value: '${totalMeca - pending}', 
                          icon: Icons.engineering_rounded, 
                          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)])
                        ),
                      ),
                      SizedBox(height: isDesktop ? 0 : 16, width: isDesktop ? 16 : 0),
                      Expanded(
                        flex: isDesktop ? 1 : 0,
                        child: _PremiumStatCard(
                          title: 'Interventions', 
                          value: '$totalInterventions', 
                          icon: Icons.build_circle_rounded, 
                          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                        ),
                      ),
                    ],
                  );
                }
              ),
              
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Revenus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Text('$currentYear', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildRevenueChart(currentYear),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Interventions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Text('$currentYear', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildInterventionsChart(currentYear),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildRevenueChart(int year) {
    return FutureBuilder<List<double>>(
      future: _revenueFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        
        final data = snapshot.data!;
        double maxY = data.reduce((a, b) => a > b ? a : b);
        if (maxY == 0) maxY = 100; // default si vide

        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true, 
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1, dashArray: [5, 5]),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
                      if (value.toInt() >= 0 && value.toInt() < 12 && value.toInt() % 2 == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(months[value.toInt()], style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == maxY || value == 0) return const Text('');
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text('${value.toInt()} DT', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 11,
              minY: 0,
              maxY: maxY * 1.2,
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(12, (index) => FlSpot(index.toDouble(), data[index])),
                  isCurved: true,
                  curveSmoothness: 0.35,
                  gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: const Color(0xFF3B82F6),
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF3B82F6).withOpacity(0.2),
                        const Color(0xFF3B82F6).withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInterventionsChart(int year) {
    return FutureBuilder<List<int>>(
      future: _interventionsCountFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        
        final data = snapshot.data!;
        double maxY = data.reduce((a, b) => a > b ? a : b).toDouble();
        if (maxY == 0) maxY = 5; // default si vide

        return SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY * 1.2,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()} interventions',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                      if (value.toInt() >= 0 && value.toInt() < 12) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(months[value.toInt()], style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 == 0 && value != 0) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text('${value.toInt()}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 5 ? maxY / 5 : 1,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(12, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data[index].toDouble(),
                      gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                      width: 14,
                      borderRadius: BorderRadius.circular(4),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY * 1.2,
                        color: Colors.grey.shade100,
                      ),
                    )
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  // ── LISTE MÉCANICIENS ─────────────────────────────────────────────────────
  Widget _buildMecaniciensList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _mecaRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        List<Mecanicien> mecas = [];
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          mecas = data.entries
              .where((e) => e.value is Map)
              .map((e) => Mecanicien.fromMap(e.key as String, e.value as Map))
              .toList();
        }

        final pending = mecas.where((m) => !m.isApproved).toList();
        final approved = mecas.where((m) => m.isApproved).toList();

        if (mecas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: const Icon(Icons.engineering_outlined, size: 64, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),
                const Text('Aucun mécanicien inscrit', style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (pending.isNotEmpty) ...[
              _SectionHeader(title: 'Demandes en attente', count: pending.length, color: const Color(0xFFF59E0B)),
              const SizedBox(height: 12),
              ...pending.map((m) => _MecanicienPremiumCard(mecanicien: m, isPending: true)),
              const SizedBox(height: 24),
            ],
            if (approved.isNotEmpty) ...[
              _SectionHeader(title: 'Mécaniciens Partenaires', count: approved.length, color: const Color(0xFF10B981)),
              const SizedBox(height: 12),
              ...approved.map((m) => _MecanicienPremiumCard(mecanicien: m, isPending: false)),
            ],
          ],
        );
      },
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────────

class _PremiumStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Gradient gradient;
  
  const _PremiumStatCard({required this.title, required this.value, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (gradient.colors.first).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 18)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }
}

class _MecanicienPremiumCard extends StatelessWidget {
  final Mecanicien mecanicien;
  final bool isPending;
  const _MecanicienPremiumCard({required this.mecanicien, required this.isPending});

  Future<void> _approve(BuildContext context) async {
    await FirebaseDatabase.instance.ref('mecaniciens/${mecanicien.id}').update({'isApproved': true});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${mecanicien.nom} a été approuvé avec succès'), backgroundColor: Colors.green));
    }
  }

  Future<void> _reject(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer le refus'),
        content: Text("Voulez-vous vraiment refuser et supprimer le profil de ${mecanicien.nom} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Refuser', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseDatabase.instance.ref('mecaniciens/${mecanicien.id}').remove();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Le profil de ${mecanicien.nom} a été supprimé'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: isPending ? Colors.orange.shade200 : Colors.transparent, width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPending ? [Colors.orange.shade300, Colors.orange.shade500] : [Colors.blue.shade300, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: (isPending ? Colors.orange : Colors.blue).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Center(
                    child: Text(mecanicien.initiales, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mecanicien.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(child: Text(mecanicien.email, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Container(color: Colors.grey.shade100, height: 1),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.handyman_rounded, size: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Spécialité', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(mecanicien.specialite, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.phone_rounded, size: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Téléphone', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(mecanicien.telephone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (isPending) ...[
            Container(color: Colors.grey.shade100, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Refuser', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Approuver ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
