import 'mileage_entry.dart';

class Vehicle {
  final String id;
  // Diagram fields
  final String marque;
  final String modele;
  final String immatriculation;
  final int kilometrageActuel; 

  // Extra features
  final int kilometrageProchVidange;
  final DateTime prochainControle;
  final double sante;
  final String clientId; 
  
  // New fields for reminders
  final DateTime dernierMiseAJourKm;
  final int rappelKmJours; // Number of days before reminding to update mileage
  
  // History of mileage for better prediction
  final List<MileageEntry> mileageHistory;

  // New field for vehicle images (max 3)
  final List<String> imageUrls;

  Vehicle({
    required this.id,
    required this.marque,
    required this.modele,
    required this.immatriculation,
    required this.kilometrageActuel,
    required this.kilometrageProchVidange,
    required this.prochainControle,
    required this.sante,
    required this.clientId,
    required this.dernierMiseAJourKm,
    this.rappelKmJours = 7,
    this.mileageHistory = const [],
    this.imageUrls = const [],
  });

  String get nomComplet => '$marque $modele';
  int get kmAvantVidange => kilometrageProchVidange - kilometrageActuel;
  bool get vidangeUrgente => kmAvantVidange < 500;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'marque': marque,
      'modele': modele,
      'immatriculation': immatriculation,
      'kilometrageActuel': kilometrageActuel,
      'kilometrageProchVidange': kilometrageProchVidange,
      'prochainControle': prochainControle.millisecondsSinceEpoch,
      'sante': sante,
      'clientId': clientId,
      'dernierMiseAJourKm': dernierMiseAJourKm.millisecondsSinceEpoch,
      'rappelKmJours': rappelKmJours,
      'mileageHistory': mileageHistory.map((e) => e.toMap()).toList(),
      'imageUrls': imageUrls,
    };
  }

  factory Vehicle.fromMap(String id, Map<dynamic, dynamic> map) {
    var history = <MileageEntry>[];
    if (map['mileageHistory'] != null) {
      final historyMap = map['mileageHistory'] as Map? ?? {};
      if (map['mileageHistory'] is List) {
        history = (map['mileageHistory'] as List)
            .where((e) => e != null)
            .map((e) => MileageEntry.fromMap(e as Map))
            .toList();
      } else {
        history = historyMap.values
            .map((e) => MileageEntry.fromMap(e as Map))
            .toList();
      }
    }

    final imageUrlsRaw = map['imageUrls'];
    List<String> imageUrls = [];
    if (imageUrlsRaw is List) {
      imageUrls = List<String>.from(imageUrlsRaw);
    }

    return Vehicle(
      id: id,
      marque: map['marque'] as String? ?? '',
      modele: map['modele'] as String? ?? '',
      immatriculation: map['immatriculation'] as String? ?? '',
      kilometrageActuel: (map['kilometrageActuel'] ?? map['kilometrage'] as num?)?.toInt() ?? 0,
      kilometrageProchVidange: (map['kilometrageProchVidange'] as num?)?.toInt() ?? 0,
      prochainControle: DateTime.fromMillisecondsSinceEpoch(
        (map['prochainControle'] as num?)?.toInt() ?? 0,
      ),
      sante: (map['sante'] as num?)?.toDouble() ?? 0.8,
      clientId: map['clientId'] as String? ?? '',
      dernierMiseAJourKm: DateTime.fromMillisecondsSinceEpoch(
        (map['dernierMiseAJourKm'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      rappelKmJours: (map['rappelKmJours'] as num?)?.toInt() ?? 7,
      mileageHistory: history,
      imageUrls: imageUrls,
    );
  }
}
