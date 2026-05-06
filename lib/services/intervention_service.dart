import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/intervention.dart';

class InterventionService {
  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: FirebaseDatabase.instance.app,
        databaseURL: 'https://pfaa-9a614-default-rtdb.firebaseio.com',
      );

  // ── Référence pour l'utilisateur connecté ─────────────────────────────────
  static DatabaseReference _userInterventionsRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    return _db.ref('interventions/$uid');
  }

  // ── Stream en temps réel ───────────────────────────────────────────────────
  static Stream<List<Intervention>> interventionsStream() {
    return _userInterventionsRef().onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .where((e) => e.value is Map)
          .map((e) => Intervention.fromMap(e.key as String, e.value as Map))
          .toList();
      // Trier par date décroissante
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // ── Ajouter une intervention ───────────────────────────────────────────────
  static Future<void> addIntervention(Intervention intervention) async {
    final ref = _userInterventionsRef().push();
    await ref.set(intervention.toMap());
  }

  // ── Modifier une intervention ──────────────────────────────────────────────
  static Future<void> updateIntervention(Intervention intervention) async {
    await _userInterventionsRef()
        .child(intervention.id)
        .update(intervention.toMap());
  }

  // ── Supprimer une intervention ─────────────────────────────────────────────
  static Future<void> deleteIntervention(String interventionId) async {
    await _userInterventionsRef().child(interventionId).remove();
  }
}
