class Vehicle {
  final String id;
  final String marque;
  final String modele;
  final String immatriculation;
  final int kilometrage;
  final int kilometrageProchVidange;
  final DateTime prochainControle;
  final double sante; // 0.0 to 1.0

  Vehicle({
    required this.id,
    required this.marque,
    required this.modele,
    required this.immatriculation,
    required this.kilometrage,
    required this.kilometrageProchVidange,
    required this.prochainControle,
    required this.sante,
  });

  String get nomComplet => '$marque $modele';

  int get kmAvantVidange => kilometrageProchVidange - kilometrage;

  bool get vidangeUrgente => kmAvantVidange < 500;

  @override
  bool operator ==(Object other) => other is Vehicle && other.id == id;

  @override
  int get hashCode => id.hashCode;


  // ── Conversion pour Firebase ──────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'marque': marque,
      'modele': modele,
      'immatriculation': immatriculation,
      'kilometrage': kilometrage,
      'kilometrageProchVidange': kilometrageProchVidange,
      'prochainControle': prochainControle.millisecondsSinceEpoch,
      'sante': sante,
    };
  }

  factory Vehicle.fromMap(String id, Map<dynamic, dynamic> map) {
    return Vehicle(
      id: id,
      marque: map['marque'] as String? ?? '',
      modele: map['modele'] as String? ?? '',
      immatriculation: map['immatriculation'] as String? ?? '',
      kilometrage: (map['kilometrage'] as num?)?.toInt() ?? 0,
      kilometrageProchVidange:
          (map['kilometrageProchVidange'] as num?)?.toInt() ?? 0,
      prochainControle: DateTime.fromMillisecondsSinceEpoch(
        (map['prochainControle'] as num?)?.toInt() ?? 0,
      ),
      sante: (map['sante'] as num?)?.toDouble() ?? 0.8,
    );
  }
}
