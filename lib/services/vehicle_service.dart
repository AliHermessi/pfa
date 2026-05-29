import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/vehicle.dart';

class VehicleService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── Stream en temps réel ───────────────────────────────────────────────────
  static Stream<List<Vehicle>> vehiclesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db.child('vehicles/$uid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      if (data is Map) {
        return data.entries
            .where((e) => e.value is Map)
            .map((e) => Vehicle.fromMap(e.key as String, e.value as Map))
            .toList();
      }
      return [];
    });
  }

  // ── Récupérer un véhicule spécifique ─────────────────────────────────────
  static Future<Vehicle?> getVehicle(String userId, String vehicleId) async {
    final snap = await _db.child('vehicles/$userId/$vehicleId').get();
    if (snap.exists && snap.value != null) {
      return Vehicle.fromMap(vehicleId, snap.value as Map);
    }
    return null;
  }

  // ── Ajouter un véhicule ───────────────────────────────────────────────────
  static Future<String> addVehicle(Vehicle vehicle) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    
    final ref = _db.child('vehicles/$uid').push();
    await ref.set(vehicle.toMap());
    return ref.key!;
  }

  // ── Modifier un véhicule ──────────────────────────────────────────────────
  static Future<void> updateVehicle(Vehicle vehicle) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    await _db.child('vehicles/$uid/${vehicle.id}').update(vehicle.toMap());
  }

  // ── Mettre à jour le kilométrage uniquement ──────────────────────────────
  static Future<void> updateVehicleMileage(String userId, String vehicleId, int newKm) async {
    await _db.child('vehicles/$userId/$vehicleId').update({
      'kilometrageActuel': newKm,
      'dernierMiseAJourKm': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── Supprimer un véhicule ─────────────────────────────────────────────────
  static Future<void> deleteVehicle(String vehicleId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    await _db.child('vehicles/$uid/$vehicleId').remove();
  }
}
