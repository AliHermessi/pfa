import 'package:firebase_database/firebase_database.dart';
import '../models/alerte.dart';

class AlerteService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static Stream<List<Alerte>> vehicleAlertsStream(String vehicleId) {
    return _db.child('alerts/$vehicleId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      if (data is Map) {
        return data.entries
            .map((e) => Alerte.fromMap(e.key as String, Map<String, dynamic>.from(e.value as Map)))
            .toList();
      }
      return [];
    });
  }

  static Future<void> createAlerte(Alerte alerte) async {
    final ref = _db.child('alerts/${alerte.vehicleId}').push();
    await ref.set(alerte.toMap());
  }

  static Future<void> resolveAlerte(String vehicleId, String alerteId) async {
    await _db.child('alerts/$vehicleId/$alerteId').update({'estResolue': true});
  }
}
