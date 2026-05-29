import 'package:firebase_database/firebase_database.dart';
import '../models/carnet_entretien.dart';
import '../models/vehicle.dart';

class CarnetService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Récupère tout l'historique d'entretien pour un véhicule spécifique
  static Stream<List<CarnetEntretien>> vehicleCarnetStream(String vehicleId) {
    return _db.child('carnets/$vehicleId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      if (data is Map) {
        return data.entries
            .map((e) => CarnetEntretien.fromMap(e.key as String, Map<String, dynamic>.from(e.value as Map)))
            .toList();
      }
      return [];
    });
  }

  /// Ajoute une nouvelle entrée dans le carnet d'entretien
  static Future<void> addEntry(CarnetEntretien entry) async {
    final ref = _db.child('carnets/${entry.vehicleId}').push();
    await ref.set(entry.toMap());
  }

  /// Met à jour une entrée existante
  static Future<void> updateEntry(CarnetEntretien entry) async {
    if (entry.id.isEmpty) {
      // Check if an entry for this component already exists to update it instead of pushing new
      final snap = await _db.child('carnets/${entry.vehicleId}').get();
      if (snap.exists) {
        final data = snap.value as Map;
        final existingKey = data.entries.firstWhere(
          (e) => e.value['composantId'] == entry.composantId,
          orElse: () => const MapEntry('', null),
        ).key;

        if (existingKey.isNotEmpty) {
          await _db.child('carnets/${entry.vehicleId}/$existingKey').update(entry.toMap());
          return;
        }
      }
      await addEntry(entry);
    } else {
      await _db.child('carnets/${entry.vehicleId}/${entry.id}').update(entry.toMap());
    }
  }

  /// Calcule la santé basée sur les composants
  /// Retourne null si moins de 4 composants renseignés
  static double? calculateHealth(Vehicle vehicle, List<CarnetEntretien> entries) {
    if (entries.length < 4) return null;

    double totalHealth = 0;
    final now = DateTime.now();

    for (var entry in entries) {
      final kmDiff = vehicle.kilometrageActuel - entry.dernierKilometrageChangement;
      final daysDiff = now.difference(entry.dateChangement).inDays;

      final usureKm = kmDiff / 40000;
      final usureTime = daysDiff / (3 * 365);

      final santeComposant = (1.0 - (usureKm > usureTime ? usureKm : usureTime)).clamp(0.0, 1.0);
      totalHealth += santeComposant;
    }

    return totalHealth / entries.length;
  }
}
