import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/app_notification.dart';

class NotificationService {
  static final _db = FirebaseDatabase.instance.ref();

  /// Envoyer une notification à un utilisateur spécifique
  static Future<void> sendNotification({
    required String userId,
    required String titre,
    required String message,
    String? interventionId,
  }) async {
    final ref = _db.child('notifications/$userId').push();
    final notif = AppNotification(
      id: ref.key!,
      userId: userId,
      titre: titre,
      message: message,
      date: DateTime.now(),
      lue: false,
      interventionId: interventionId,
    );
    await ref.set(notif.toMap());
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

      // Trier par date décroissante (les plus récentes en premier)
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// Marquer une notification comme lue
  static Future<void> markAsRead(String notificationId) async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) return;

    await _db.child('notifications/$userUid/$notificationId').update({
      'lue': true,
    });
  }

  /// Marquer toutes les notifications comme lues
  static Future<void> markAllAsRead() async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) return;

    final snapshot = await _db.child('notifications/$userUid').get();
    if (snapshot.value != null) {
      final map = snapshot.value as Map<dynamic, dynamic>;
      final Map<String, dynamic> updates = {};
      map.forEach((key, value) {
        updates['$key/lue'] = true;
      });
      await _db.child('notifications/$userUid').update(updates);
    }
  }
}
