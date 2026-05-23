import 'package:firebase_database/firebase_database.dart';

class RatingService {
  static final _db = FirebaseDatabase.instance.ref();

  static Future<void> submitRating(
      String mecanicienId, String interventionId, String userId, int note) async {
    // 1. Sauvegarder l'évaluation
    await _db.child('evaluations/$mecanicienId/$interventionId').set({
      'userId': userId,
      'note': note,
      'date': ServerValue.timestamp,
    });

    // 2. Marquer l'intervention comme notée
    await _db.child('interventions/$interventionId').update({
      'noteClient': note,
    });

    // 3. Recalculer la moyenne du mécanicien
    final evalsSnapshot = await _db.child('evaluations/$mecanicienId').get();
    if (evalsSnapshot.value != null) {
      final map = evalsSnapshot.value as Map<dynamic, dynamic>;
      double sum = 0;
      int count = 0;
      map.forEach((key, value) {
        if (value is Map && value['note'] != null) {
          sum += (value['note'] as num).toDouble();
          count++;
        }
      });

      final moyenne = count > 0 ? sum / count : 0.0;

      // 4. Mettre à jour le mécanicien
      await _db.child('mecaniciens/$mecanicienId').update({
        'note': double.parse(moyenne.toStringAsFixed(1)),
        'nombreAvis': count,
      });
    }
  }
}
