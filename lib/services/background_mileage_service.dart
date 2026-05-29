import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart';

class BackgroundMileageService {
  static const String notificationChannelId = 'mileage_tracking_channel';
  static const int notificationId = 888;

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Mileage Tracking',
      description: 'This channel is used for tracking car mileage in background.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Mode Conduite Actif',
        initialNotificationContent: 'Calcul du kilométrage en cours...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    String? vehicleId;
    String? userId;
    double totalDistance = 0.0;
    Position? lastPosition;
    StreamSubscription<Position>? positionStream;

    void updateNotification(double distance) {
      if (service is AndroidServiceInstance) {
        flutterLocalNotificationsPlugin.show(
          notificationId,
          'Mode Conduite Actif',
          'Distance parcourue : ${(distance / 1000).toStringAsFixed(2)} km',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId,
              'Mileage Tracking',
              ongoing: true,
              icon: '@mipmap/ic_launcher',
              onlyAlertOnce: true,
              // Note: Action buttons in notifications usually require a broadcast receiver
              // For simplicity, we keep the notification non-swipable as requested.
            ),
          ),
        );
      }
    }

    service.on('setVehicle').listen((event) {
      vehicleId = event?['vehicleId'];
      userId = event?['userId'];
      totalDistance = 0.0;
      lastPosition = null;
      
      // Start location stream
      positionStream?.cancel();
      positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (lastPosition != null) {
          double distance = Geolocator.distanceBetween(
            lastPosition!.latitude,
            lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          
          if (distance > 2) { // 2m filter for jitter
            totalDistance += distance;
            updateNotification(totalDistance);
            
            // Periodically sync every 1km while driving
            if (totalDistance >= 1000 && userId != null && vehicleId != null) {
              _updateFirebaseMileage(userId!, vehicleId!, 1000);
              totalDistance -= 1000;
            }
          }
        }
        lastPosition = position;
      });
    });

    service.on('stopService').listen((event) async {
      positionStream?.cancel();
      if (userId != null && vehicleId != null && totalDistance >= 10) {
        await _updateFirebaseMileage(userId!, vehicleId!, totalDistance);
      }
      service.stopSelf();
    });
  }

  static Future<void> _updateFirebaseMileage(String userId, String vehicleId, double distanceInMeters) async {
    try {
      final ref = FirebaseDatabase.instance.ref('vehicles/$userId/$vehicleId');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        int currentKm = (data['kilometrageActuel'] as num).toInt();
        int kmToAdd = (distanceInMeters / 1000).floor();
        
        // We track fractional km in distanceInMeters, but update the integer km in DB
        // If we want to be precise, we could store km as double in DB. 
        // For now, let's just add the floor and wait for next full km.
        if (kmToAdd > 0) {
          await ref.update({
            'kilometrageActuel': currentKm + kmToAdd,
            'dernierMiseAJourKm': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    } catch (e) {
      // Background logging
    }
  }
}
