class Utilisateur {
  final String id;
  final String email;
  final String? motDePasse;
  final String telephone;
  final String role; // 'user' (client), 'mecanicien', 'admin'
  final String nom;
  final String? photoUrl;

  Utilisateur({
    required this.id,
    required this.email,
    this.motDePasse,
    required this.telephone,
    required this.role,
    required this.nom,
    this.photoUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Utilisateur && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'telephone': telephone,
      'role': role,
      'nom': nom,
      'photoUrl': photoUrl,
    };
  }

  factory Utilisateur.fromMap(String id, Map<dynamic, dynamic> map) {
    return Utilisateur(
      id: id,
      email: map['email'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      nom: map['nom'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
    );
  }
}
