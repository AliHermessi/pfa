import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_message.dart';
import 'notification_service.dart';

class ChatService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── Envoyer un message ─────────────────────────────────────────────────────
  static Future<void> sendMessage({
    required String interventionId,
    required String text,
    required String recipientId,
    required String senderName,
    required String vehiculeNom,
  }) async {
    final senderId = FirebaseAuth.instance.currentUser?.uid;
    if (senderId == null) throw Exception('Utilisateur non connecté');

    final ref = _db.child('chats/$interventionId').push();
    final message = ChatMessage(
      id: ref.key!,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    );

    await ref.set(message.toMap());

    try {
      await NotificationService.sendNotification(
        userId: recipientId,
        titre: 'Nouveau message de $senderName',
        message: '[$vehiculeNom] : $text',
        interventionId: interventionId,
      );
    } catch (_) {
      // Ignorer l'erreur pour ne pas bloquer l'envoi du message
    }
  }

  // ── Stream des messages ────────────────────────────────────────────────────
  static Stream<List<ChatMessage>> getMessagesStream(String interventionId) {
    return _db.child('chats/$interventionId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .where((e) => e.value is Map)
          .map((e) => ChatMessage.fromMap(e.key as String, e.value as Map))
          .toList();

      // Trier par date décroissante (les plus récents en premier pour l'affichage inversé)
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }
}
