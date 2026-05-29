import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/mecanicien.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../services/export_service.dart';
import '../login_screen.dart';
import 'user_management_screen.dart';
import 'mecanicien_profile_screen.dart';

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
            content: const Text("Fichier sauvegardé avec succès !"), 
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.green,
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
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(title, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), onPressed: () => _exportData(false)),
            IconButton(icon: const Icon(Icons.table_chart, color: Colors.green), onPressed: () => _exportData(true)),
          ],
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
            onPressed: () async {
              await AuthService.logout();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
          const SizedBox(width: 8),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFF3B82F6),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Utilisateurs'),
          BottomNavigationBarItem(icon: Icon(Icons.engineering_rounded), label: 'Mécaniciens'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return StreamBuilder<DatabaseEvent>(
      stream: _mecaStream,
      builder: (context, mecaSnapshot) {
        return StreamBuilder<DatabaseEvent>(
          stream: _interventionsStream,
          builder: (context, interSnapshot) {
            int totalMeca = 0, totalInterventions = 0, pending = 0, completedInter = 0;

            if (mecaSnapshot.hasData && mecaSnapshot.data!.snapshot.value != null) {
              final data = mecaSnapshot.data!.snapshot.value as Map;
              data.forEach((_, v) {
                if (v is Map) {
                  totalMeca++;
                  if (v['isApproved'] == false) pending++;
                }
              });
            }

            if (interSnapshot.hasData && interSnapshot.data!.snapshot.value != null) {
              final data = interSnapshot.data!.snapshot.value as Map;
              data.forEach((_, userInter) {
                if (userInter is Map) {
                  userInter.forEach((_, inter) {
                    if (inter is Map) {
                      totalInterventions++;
                      final status = inter['statut'];
                      if (status == 1 || status.toString() == 'termine') completedInter++;
                    }
                  });
                }
              });
            }

            double totalRevenue = completedInter * 10.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pending > 0)
                    _buildPendingAlert(pending),
                  
                  const Text('Statistiques Clés', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 16),
                  
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _PremiumStatCard(
                        title: 'Mécani. Actifs', 
                        value: '${totalMeca - pending}', 
                        icon: Icons.engineering, 
                        color: const Color(0xFF3B82F6)
                      ),
                      _PremiumStatCard(
                        title: 'Interventions', 
                        value: '$totalInterventions', 
                        icon: Icons.build_circle, 
                        color: const Color(0xFF10B981)
                      ),
                      _PremiumStatCard(
                        title: 'Revenu Total', 
                        value: '$totalRevenue DT', 
                        icon: Icons.monetization_on, 
                        color: const Color(0xFF8B5CF6)
                      ),
                      _PremiumStatCard(
                        title: 'En attente', 
                        value: '$pending', 
                        icon: Icons.hourglass_top, 
                        color: const Color(0xFFF59E0B)
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  _buildChartContainer('Revenus (Commissions 10 DT)', _buildRevenueChart()),
                  const SizedBox(height: 24),
                  _buildChartContainer('Volume d\'Interventions', _buildInterventionsChart()),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingAlert(int count) {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.notification_important, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('$count nouveau(x) mécanicien(s) attendent votre validation', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 24),
          SizedBox(height: 200, child: chart),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return FutureBuilder<List<double>>(
      future: _revenueFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        double maxY = data.reduce((a, b) => a > b ? a : b);
        if (maxY < 50) maxY = 50;
        return LineChart(LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text('${v.toInt()} ', style: const TextStyle(fontSize: 10, color: Colors.grey)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
              const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
              if (v % 2 == 0 && v < 12) return Text(months[v.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey));
              return const Text('');
            })),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(12, (i) => FlSpot(i.toDouble(), data[i])),
              isCurved: true,
              color: const Color(0xFF3B82F6),
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF3B82F6).withOpacity(0.1)),
            ),
          ],
          minY: 0,
          maxY: maxY * 1.2,
        ));
      },
    );
  }

  Widget _buildInterventionsChart() {
    return FutureBuilder<List<int>>(
      future: _interventionsCountFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        return BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
              const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
              return Text(months[v.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey));
            })),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(12, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: data[i].toDouble(), color: const Color(0xFF10B981), width: 12, borderRadius: BorderRadius.circular(4))])),
        ));
      },
    );
  }

  Widget _buildMecaniciensList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _mecaRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        List<Mecanicien> mecas = [];
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map;
          mecas = data.entries.map((e) => Mecanicien.fromMap(e.key as String, e.value as Map)).toList();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: mecas.length,
          itemBuilder: (context, index) => _MecanicienPremiumCard(mecanicien: mecas[index]),
        );
      },
    );
  }
}

class _PremiumStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _PremiumStatCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _MecanicienPremiumCard extends StatelessWidget {
  final Mecanicien mecanicien;
  const _MecanicienPremiumCard({required this.mecanicien});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MecanicienProfileScreen(mecanicien: mecanicien))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: mecanicien.isApproved ? Colors.transparent : Colors.orange.shade100)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: mecanicien.isApproved ? const Color(0xFF3B82F6) : Colors.orange, child: Text(mecanicien.initiales, style: const TextStyle(color: Colors.white))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mecanicien.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(mecanicien.specialite, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ),
            if (!mecanicien.isApproved)
              const Icon(Icons.pending, color: Colors.orange)
            else
              const Icon(Icons.verified, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
