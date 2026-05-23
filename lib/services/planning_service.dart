import 'package:firebase_database/firebase_database.dart';

class PlanningService {
  static final _db = FirebaseDatabase.instance.ref();

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Récupère la liste des créneaux horaires (int) occupés pour un mécanicien à une date donnée
  static Future<List<int>> getCreneauxOccupes(String mecanicienId, DateTime date) async {
    final dateStr = _formatDate(date);
    final snapshot = await _db.child('planning/$mecanicienId/$dateStr').get();
    
    if (snapshot.value == null) return [];
    
    final map = snapshot.value as Map<dynamic, dynamic>;
    final occupes = <int>[];
    
    map.forEach((key, value) {
      if (value == true) { // true = occupé
        final heure = int.tryParse(key.toString());
        if (heure != null) occupes.add(heure);
      }
    });
    
    return occupes;
  }

  /// Bloque un créneau lors d'une réservation
  static Future<void> bloquerCreneau(String mecanicienId, DateTime date) async {
    final dateStr = _formatDate(date);
    final heureStr = date.hour.toString();
    
    await _db.child('planning/$mecanicienId/$dateStr').update({
      heureStr: true,
    });
  }

  /// Libère un créneau (ex: si l'intervention est annulée)
  static Future<void> libererCreneau(String mecanicienId, DateTime date) async {
    final dateStr = _formatDate(date);
    final heureStr = date.hour.toString();
    
    await _db.child('planning/$mecanicienId/$dateStr/$heureStr').remove();
  }
}
