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
    
    // If vehicle.id is empty, generate a new key, otherwise use the one provided
    final ref = vehicle.id.isEmpty 
        ? _db.child('vehicles/$uid').push()
        : _db.child('vehicles/$uid/${vehicle.id}');
    
    final data = vehicle.toMap();
    if (vehicle.id.isEmpty) {
       data['id'] = ref.key;
    }
    
    // Initialize history with starting mileage if > 0
    if (vehicle.kilometrageActuel > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      data['mileageHistory'] = {
        'initial': {
          'date': now,
          'kilometrage': vehicle.kilometrageActuel,
        }
      };
    }
    
    await ref.set(data);
    return ref.key!;
  }

  // ── Modifier un véhicule ──────────────────────────────────────────────────
  static Future<void> updateVehicle(Vehicle vehicle) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    
    // Check if mileage changed to update history
    final oldVehicle = await getVehicle(uid, vehicle.id);
    if (oldVehicle != null && oldVehicle.kilometrageActuel != vehicle.kilometrageActuel) {
      await updateVehicleMileage(uid, vehicle.id, vehicle.kilometrageActuel);
    }

    final data = vehicle.toMap();
    data.remove('mileageHistory'); // Managed separately
    
    await _db.child('vehicles/$uid/${vehicle.id}').update(data);
  }

  // ── Mettre à jour le kilométrage uniquement ──────────────────────────────
  static Future<void> updateVehicleMileage(String userId, String vehicleId, int newKm) async {
    final ref = _db.child('vehicles/$userId/$vehicleId');
    final snapshot = await ref.get();
    
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      final currentKm = (data['kilometrageActuel'] as num?)?.toInt() ?? 0;
      
      if (newKm > currentKm) {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        await ref.update({
          'kilometrageActuel': newKm,
          'dernierMiseAJourKm': now,
        });

        await ref.child('mileageHistory').push().set({
          'date': now,
          'kilometrage': newKm,
        });
      }
    }
  }

  // ── Supprimer un véhicule ─────────────────────────────────────────────────
  static Future<void> deleteVehicle(String vehicleId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    await _db.child('vehicles/$uid/$vehicleId').remove();
  }
}
