import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/user/user_dashboard_screen.dart';
import 'screens/mecanic/mecanic_dashboard.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/notification_service.dart';
import 'services/background_mileage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting for French locales
  try {
    await initializeDateFormatting('fr_FR', null);
    Intl.defaultLocale = 'fr_FR';
  } catch (e) {
    debugPrint("Intl initialization error: $e");
  }
  
  // Initialize Firebase with check to prevent "duplicate-app" error on hot restart
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }
  
  // Initialize local notifications
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint("Notification initialization error: $e");
  }

  // Initialize Background Mileage Service
  try {
    await BackgroundMileageService.initializeService();
  } catch (e) {
    debugPrint("Background service initialization error: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/user_dashboard': (context) => const UserDashboardScreen(),
        '/mecanicien_dashboard': (context) => const MechanicDashboard(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
      },
    );
  }
}
