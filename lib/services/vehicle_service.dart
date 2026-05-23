import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/vehicle.dart';

class VehicleService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── Référence pour l'utilisateur connecté ─────────────────────────────────
  static DatabaseReference _userVehiclesRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    return _db.child('vehicles/$uid');
  }

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

  // ── Ajouter un véhicule ───────────────────────────────────────────────────
  static Future<void> addVehicle(Vehicle vehicle) async {
    final ref = _userVehiclesRef().push();
    await ref.set(vehicle.toMap());
  }

  // ── Modifier un véhicule ──────────────────────────────────────────────────
  static Future<void> updateVehicle(Vehicle vehicle) async {
    await _userVehiclesRef().child(vehicle.id).update(vehicle.toMap());
  }

  // ── Supprimer un véhicule ─────────────────────────────────────────────────
  static Future<void> deleteVehicle(String vehicleId) async {
    await _userVehiclesRef().child(vehicleId).remove();
  }
}
