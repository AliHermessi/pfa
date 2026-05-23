class Mecanicien {
  final String id;
  final String nom;
  final String email;
  final String specialite;
  final double note;
  final int nombreAvis;
  final double distanceKm;
  final bool disponible;
  final String telephone;
  final bool isApproved;
  final String role;
  final int heuresDebut;
  final int heuresFin;
  // ── Localisation temps réel ─────────────────────────────────────────────
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen;

  Mecanicien({
    required this.id,
    required this.nom,
    required this.email,
    required this.specialite,
    this.note = 0.0,
    this.nombreAvis = 0,
    this.distanceKm = 0.0,
    this.disponible = true,
    required this.telephone,
    this.isApproved = false,
    this.role = 'mecanicien',
    this.heuresDebut = 8,
    this.heuresFin = 18,
    this.latitude,
    this.longitude,
    this.lastSeen,
  });

  /// Vrai si le mécanicien a partagé sa position récemment (< 5 minutes)
  bool get hasLiveLocation {
    if (latitude == null || longitude == null) return false;
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!).inMinutes < 5;
  }

  String get initiales {
    final parts = nom.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.isNotEmpty ? nom.substring(0, nom.length >= 2 ? 2 : 1).toUpperCase() : '??';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'email': email,
      'specialite': specialite,
      'note': note,
      'nombreAvis': nombreAvis,
      'distanceKm': distanceKm,
      'disponible': disponible,
      'telephone': telephone,
      'isApproved': isApproved,
      'role': role,
      'heuresDebut': heuresDebut,
      'heuresFin': heuresFin,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (lastSeen != null) 'lastSeen': lastSeen!.millisecondsSinceEpoch,
    };
  }

  factory Mecanicien.fromMap(String id, Map<dynamic, dynamic> map) {
    return Mecanicien(
      id: id,
      nom: map['nom'] as String? ?? '',
      email: map['email'] as String? ?? '',
      specialite: map['specialite'] as String? ?? '',
      note: (map['note'] as num?)?.toDouble() ?? 0.0,
      nombreAvis: (map['nombreAvis'] as num?)?.toInt() ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      disponible: map['disponible'] as bool? ?? true,
      telephone: map['telephone'] as String? ?? '',
      isApproved: map['isApproved'] as bool? ?? false,
      role: map['role'] as String? ?? 'mecanicien',
      heuresDebut: (map['heuresDebut'] as num?)?.toInt() ?? 8,
      heuresFin: (map['heuresFin'] as num?)?.toInt() ?? 18,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      lastSeen: map['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['lastSeen'] as num).toInt())
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Mecanicien &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
