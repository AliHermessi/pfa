enum InterventionStatut { enCours, termine, planifie }

enum InterventionType { vidange, pneus, batterie, freins, filtreAir, autre }

class Intervention {
  final String id;
  final String vehiculeId;
  final String vehiculeNom;
  final InterventionType type;
  final String description;
  final List<String> pieces;
  final double prixEstime;
  final DateTime date;
  final InterventionStatut statut;
  final String? mecanicienNom;

  Intervention({
    required this.id,
    required this.vehiculeId,
    required this.vehiculeNom,
    required this.type,
    required this.description,
    required this.pieces,
    required this.prixEstime,
    required this.date,
    required this.statut,
    this.mecanicienNom,
  });

  String get typeLabel {
    switch (type) {
      case InterventionType.vidange:
        return 'Vidange';
      case InterventionType.pneus:
        return 'Pneus';
      case InterventionType.batterie:
        return 'Batterie';
      case InterventionType.freins:
        return 'Freins';
      case InterventionType.filtreAir:
        return 'Filtre Air';
      case InterventionType.autre:
        return 'Autre';
    }
  }

  String get statutLabel {
    switch (statut) {
      case InterventionStatut.enCours:
        return 'En cours';
      case InterventionStatut.termine:
        return 'Terminé';
      case InterventionStatut.planifie:
        return 'Planifié';
    }
  }

  // ── Conversion pour Firebase ──────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'vehiculeId': vehiculeId,
      'vehiculeNom': vehiculeNom,
      'type': type.index,
      'description': description,
      'pieces': pieces,
      'prixEstime': prixEstime,
      'date': date.millisecondsSinceEpoch,
      'statut': statut.index,
      'mecanicienNom': mecanicienNom,
    };
  }

  factory Intervention.fromMap(String id, Map<dynamic, dynamic> map) {
    final piecesRaw = map['pieces'];
    final List<String> pieces = piecesRaw is List
        ? piecesRaw.map((e) => e.toString()).toList()
        : <String>[];

    return Intervention(
      id: id,
      vehiculeId: map['vehiculeId'] as String? ?? '',
      vehiculeNom: map['vehiculeNom'] as String? ?? '',
      type: InterventionType.values[(map['type'] as num?)?.toInt() ?? 0],
      description: map['description'] as String? ?? '',
      pieces: pieces,
      prixEstime: (map['prixEstime'] as num?)?.toDouble() ?? 0,
      date: DateTime.fromMillisecondsSinceEpoch(
        (map['date'] as num?)?.toInt() ?? 0,
      ),
      statut:
          InterventionStatut.values[(map['statut'] as num?)?.toInt() ?? 0],
      mecanicienNom: map['mecanicienNom'] as String?,
    );
  }
}
