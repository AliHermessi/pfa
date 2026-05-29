import 'utilisateur.dart';

class Administrateur extends Utilisateur {
  Administrateur({
    required super.id,
    required super.email,
    super.motDePasse,
    required super.telephone,
    required super.nom,
    super.photoUrl,
    super.role = 'admin',
  });

  factory Administrateur.fromMap(String id, Map<dynamic, dynamic> map) {
    return Administrateur(
      id: id,
      email: map['email'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String? ?? 'admin',
    );
  }
}
