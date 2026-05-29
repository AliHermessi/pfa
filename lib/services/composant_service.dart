import 'package:firebase_database/firebase_database.dart';
import '../models/composant.dart';

class ComposantService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Récupère la liste globale des composants disponibles
  static Stream<List<Composant>> allComposantsStream() {
    return _db.child('composants').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      if (data is Map) {
        return data.entries
            .map((e) => Composant.fromMap(e.key as String, Map<String, dynamic>.from(e.value as Map)))
            .toList();
      }
      return [];
    });
  }

  static Future<void> addComposant(Composant composant) async {
    final ref = _db.child('composants').push();
    await ref.set(composant.toMap());
  }
}
