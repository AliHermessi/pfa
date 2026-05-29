import 'utilisateur.dart';

class Client extends Utilisateur {
  final String adresse;

  Client({
    required super.id,
    required super.email,
    super.motDePasse,
    required super.telephone,
    required super.nom,
    required this.adresse,
    super.photoUrl,
    super.role = 'user',
  });

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['adresse'] = adresse;
    return map;
  }

  factory Client.fromMap(String id, Map<dynamic, dynamic> map) {
    return Client(
      id: id,
      email: map['email'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      adresse: map['adresse'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String? ?? 'user',
    );
  }
}
