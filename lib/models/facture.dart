class FactureItem {
  final String description;
  final double prix;
  final String categorie; // 'PIECE', 'FLUIDE', 'SERVICE'

  FactureItem({
    required this.description,
    required this.prix,
    this.categorie = 'PIECE',
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'prix': prix,
      'categorie': categorie,
    };
  }

  factory FactureItem.fromMap(Map<dynamic, dynamic> map) {
    return FactureItem(
      description: map['description'] as String? ?? '',
      prix: (map['prix'] as num?)?.toDouble() ?? 0.0,
      categorie: map['categorie'] as String? ?? 'PIECE',
    );
  }
}

class Facture {
  final String id;
  final String interventionId;
  final String vehicleId;
  final String mecanicienId;
  final DateTime date;
  final List<FactureItem> items;
  final double total;

  Facture({
    required this.id,
    required this.interventionId,
    required this.vehicleId,
    required this.mecanicienId,
    required this.date,
    required this.items,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'interventionId': interventionId,
      'vehicleId': vehicleId,
      'mecanicienId': mecanicienId,
      'date': date.millisecondsSinceEpoch,
      'items': items.map((i) => i.toMap()).toList(),
      'total': total,
    };
  }

  factory Facture.fromMap(String id, Map<dynamic, dynamic> map) {
    final itemsRaw = map['items'] as List?;
    final items = itemsRaw != null
        ? itemsRaw.map((e) => FactureItem.fromMap(e as Map)).toList()
        : <FactureItem>[];

    return Facture(
      id: id,
      interventionId: map['interventionId'] as String? ?? '',
      vehicleId: map['vehicleId'] as String? ?? '',
      mecanicienId: map['mecanicienId'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        (map['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      items: items,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
