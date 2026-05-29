class Composant {
  final String id;
  final String nom;
  final int seuilKilometrageMax;
  final String categorie; // 'PIECE', 'FLUIDE', 'CONTROLE'

  Composant({
    required this.id,
    required this.nom,
    required this.seuilKilometrageMax,
    this.categorie = 'PIECE',
  });

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'seuilKilometrageMax': seuilKilometrageMax,
      'categorie': categorie,
    };
  }

  factory Composant.fromMap(String id, Map<dynamic, dynamic> map) {
    return Composant(
      id: id,
      nom: map['nom'] as String? ?? '',
      seuilKilometrageMax: (map['seuilKilometrageMax'] as num?)?.toInt() ?? 0,
      categorie: map['categorie'] as String? ?? 'PIECE',
    );
  }
}
