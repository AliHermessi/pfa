import 'package:firebase_database/firebase_database.dart';
import '../models/review.dart';

class RatingService {
  static final _db = FirebaseDatabase.instance.ref();

  static Future<void> submitRating({
    required String mecanicienId,
    required String userId,
    required int note,
    String? commentaire,
    String? interventionId,
  }) async {
    final reviewId = interventionId ?? _db.child('evaluations/$mecanicienId').push().key!;

    // 1. Sauvegarder l'évaluation détaillée
    await _db.child('evaluations/$mecanicienId/$reviewId').set({
      'userId': userId,
      'note': note,
      'commentaire': commentaire,
      'date': DateTime.now().millisecondsSinceEpoch,
    });

    // 2. Si lié à une intervention, marquer comme notée
    if (interventionId != null) {
      await _db.child('interventions/$interventionId').update({
        'noteClient': note,
      });
    }

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

  static Stream<List<Review>> getMecanicienReviews(String mecanicienId) {
    return _db.child('evaluations/$mecanicienId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final map = data as Map<dynamic, dynamic>;
      return map.entries.map((e) => Review.fromMap(e.key as String, e.value as Map)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }
}
