import 'utilisateur.dart';

class Mecanicien extends Utilisateur {
  // Fields from Diagram
  final String nomGarage;
  final String adresseGarage;
  final String statutCompte; // e.g., 'actif', 'en_attente'

  // Extra Features
  final String specialite;
  final double note;
  final int nombreAvis;
  final double distanceKm;
  final bool disponible;
  final bool isApproved;
  
  // Opening hours and days
  final int heuresDebut; // e.g., 8
  final int minutesDebut; // e.g., 0
  final int heuresFin;   // e.g., 18
  final int minutesFin;   // e.g., 0
  final List<int> joursOuverture; // 1=Mon, 7=Sun. Default [1,2,3,4,5]

  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen;

  Mecanicien({
    required super.id,
    required super.email,
    super.motDePasse,
    required super.telephone,
    required super.nom,
    required this.nomGarage,
    required this.adresseGarage,
    required this.statutCompte,
    super.photoUrl,
    this.specialite = '',
    this.note = 0.0,
    this.nombreAvis = 0,
    this.distanceKm = 0.0,
    this.disponible = true,
    this.isApproved = false,
    super.role = 'mecanicien',
    this.heuresDebut = 8,
    this.minutesDebut = 0,
    this.heuresFin = 18,
    this.minutesFin = 0,
    this.joursOuverture = const [1, 2, 3, 4, 5],
    this.latitude,
    this.longitude,
    this.lastSeen,
  });

  bool get hasLiveLocation {
    if (latitude == null || longitude == null || lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!).inMinutes < 5;
  }

  String get initiales {
    final parts = nom.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.isNotEmpty ? nom.substring(0, nom.length >= 2 ? 2 : 1).toUpperCase() : '??';
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'nomGarage': nomGarage,
      'adresseGarage': adresseGarage,
      'statutCompte': statutCompte,
      'specialite': specialite,
      'note': note,
      'nombreAvis': nombreAvis,
      'distanceKm': distanceKm,
      'disponible': disponible,
      'isApproved': isApproved,
      'heuresDebut': heuresDebut,
      'minutesDebut': minutesDebut,
      'heuresFin': heuresFin,
      'minutesFin': minutesFin,
      'joursOuverture': joursOuverture,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (lastSeen != null) 'lastSeen': lastSeen!.millisecondsSinceEpoch,
    });
    return map;
  }

  factory Mecanicien.fromMap(String id, Map<dynamic, dynamic> map) {
    return Mecanicien(
      id: id,
      email: map['email'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      role: map['role'] as String? ?? 'mecanicien',
      nomGarage: map['nomGarage'] as String? ?? '',
      adresseGarage: map['adresseGarage'] as String? ?? '',
      statutCompte: map['statutCompte'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      specialite: map['specialite'] as String? ?? '',
      note: (map['note'] as num?)?.toDouble() ?? 0.0,
      nombreAvis: (map['nombreAvis'] as num?)?.toInt() ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      disponible: map['disponible'] as bool? ?? true,
      isApproved: map['isApproved'] as bool? ?? false,
      heuresDebut: (map['heuresDebut'] as num?)?.toInt() ?? 8,
      minutesDebut: (map['minutesDebut'] as num?)?.toInt() ?? 0,
      heuresFin: (map['heuresFin'] as num?)?.toInt() ?? 18,
      minutesFin: (map['minutesFin'] as num?)?.toInt() ?? 0,
      joursOuverture: (map['joursOuverture'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [1, 2, 3, 4, 5],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      lastSeen: map['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['lastSeen'] as num).toInt())
          : null,
    );
  }
}
