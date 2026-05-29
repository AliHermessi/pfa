class CarnetEntretien {
  final String id;
  final int dernierKilometrageChangement;
  final DateTime dateChangement;
  final double niveauUsure;
  final String vehicleId;
  final String composantId;
  final String? nomComposantCustom;
  final String categorie; // Added to simplify filtering in history: 'PIECE', 'FLUIDE', 'CONTROLE'

  CarnetEntretien({
    required this.id,
    required this.dernierKilometrageChangement,
    required this.dateChangement,
    required this.niveauUsure,
    required this.vehicleId,
    required this.composantId,
    this.nomComposantCustom,
    this.categorie = 'PIECE',
  });

  Map<String, dynamic> toMap() {
    return {
      'dernierKilometrageChangement': dernierKilometrageChangement,
      'dateChangement': dateChangement.millisecondsSinceEpoch,
      'niveauUsure': niveauUsure,
      'vehicleId': vehicleId,
      'composantId': composantId,
      'categorie': categorie,
      if (nomComposantCustom != null) 'nomComposantCustom': nomComposantCustom,
    };
  }

  factory CarnetEntretien.fromMap(String id, Map<dynamic, dynamic> map) {
    return CarnetEntretien(
      id: id,
      dernierKilometrageChangement: (map['dernierKilometrageChangement'] as num?)?.toInt() ?? 0,
      dateChangement: DateTime.fromMillisecondsSinceEpoch(
        (map['dateChangement'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      niveauUsure: (map['niveauUsure'] as num?)?.toDouble() ?? 0.0,
      vehicleId: map['vehicleId'] as String? ?? '',
      composantId: map['composantId'] as String? ?? '',
      nomComposantCustom: map['nomComposantCustom'] as String?,
      categorie: map['categorie'] as String? ?? 'PIECE',
    );
  }
}
