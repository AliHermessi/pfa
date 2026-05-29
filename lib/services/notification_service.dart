import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';

class NotificationService {
  static final _db = FirebaseDatabase.instance.ref();
  static final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _localNotif.initialize(initializationSettings);
    _initialized = true;
  }

  /// Envoyer une notification à un utilisateur spécifique (Firebase + Local)
  static Future<void> sendNotification({
    required String userId,
    required String titre,
    required String message,
    NotificationGravite gravite = NotificationGravite.info,
    String? interventionId,
    String? alerteId,
    bool onlyLocal = false,
  }) async {
    // 1. Local Notification (Always shown in notification bar)
    await _showLocalNotification(titre, message);

    if (onlyLocal) return;

    // 2. Check for duplicates in Firebase (In-app notification page)
    // We only skip if an identical unread notification exists
    final snapshot = await _db.child('notifications/$userId').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final exists = data.values.any((n) => 
        n['titre'] == titre && 
        n['message'] == message && 
        n['estLu'] == false
      );
      if (exists) return; // Don't duplicate in the in-app list
    }

    // 3. Push to Firebase
    final ref = _db.child('notifications/$userId').push();
    final notif = AppNotification(
      id: ref.key!,
      userId: userId,
      titre: titre,
      message: message,
      dateEnvoi: DateTime.now(),
      estLu: false,
      gravite: gravite,
      interventionId: interventionId,
      alerteId: alerteId,
    );
    await ref.set(notif.toMap());
  }

  static Future<void> _showLocalNotification(String title, String body) async {
    await init();
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'autocare_channel_id',
      'AutoCare Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotif.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  /// Écouter les notifications de l'utilisateur connecté
  static Stream<List<AppNotification>> getUserNotificationsStream() {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) return Stream.value([]);

    return _db.child('notifications/$userUid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .where((e) => e.value is Map)
          .map((e) => AppNotification.fromMap(e.key as String, e.value as Map))
          .toList();

      list.sort((a, b) => b.dateEnvoi.compareTo(a.dateEnvoi));
      return list;
    });
  }

  static Future<void> markAsRead(String notificationId) async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) return;
    await _db.child('notifications/$userUid/$notificationId').update({'estLu': true});
  }

  static Future<void> markAllAsRead() async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) return;

    final snapshot = await _db.child('notifications/$userUid').get();
    if (snapshot.value != null) {
      final map = snapshot.value as Map<dynamic, dynamic>;
      final Map<String, dynamic> updates = {};
      map.forEach((key, value) {
        updates['$key/estLu'] = true;
      });
      await _db.child('notifications/$userUid').update(updates);
    }
  }
}
