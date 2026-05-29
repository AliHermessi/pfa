enum InterventionStatut { enCours, termine, planifie, enAttente, annule }

enum InterventionType { piece, fluide, controle, autre }

class InterventionTask {
  final InterventionType type;
  final String? name; // Name of the part (required for PIECE, FLUIDE)
  final String? description; // Optional for PIECE, FLUIDE, CONTROLE. Required for AUTRE (min 15 chars)

  InterventionTask({
    required this.type,
    this.name,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'name': name,
      'description': description,
    };
  }

  factory InterventionTask.fromMap(Map<dynamic, dynamic> map) {
    return InterventionTask(
      type: InterventionType.values[(map['type'] as num?)?.toInt() ?? 0],
      name: map['name'] as String?,
      description: map['description'] as String?,
    );
  }

  String get label {
    switch (type) {
      case InterventionType.piece: return 'Pièce : ${name ?? ""}';
      case InterventionType.fluide: return 'Fluide : ${name ?? ""}';
      case InterventionType.controle: return 'Contrôle';
      case InterventionType.autre: return 'Autre';
    }
  }
}

class Intervention {
  final String id;
  final DateTime date;
  final String heure;
  final String statutLabelDiagram;

  final String vehiculeId;
  final String userId;
  final String? mecanicienId;
  final String? alerteId;

  final String vehiculeNom;
  final List<InterventionTask> tasks;
  final double prixEstime;
  final InterventionStatut statut;
  final String? mecanicienNom;
  final int? noteClient;
  final bool estPaye;
  final int? kilometrageCompteur; // Added for predictive maintenance

  Intervention({
    required this.id,
    required this.date,
    required this.heure,
    required this.statutLabelDiagram,
    required this.vehiculeId,
    required this.userId,
    this.mecanicienId,
    this.alerteId,
    required this.vehiculeNom,
    required this.tasks,
    required this.prixEstime,
    required this.statut,
    this.mecanicienNom,
    this.noteClient,
    this.estPaye = false,
    this.kilometrageCompteur,
  });

  String get typeLabel {
    if (tasks.isEmpty) return 'Intervention';
    if (tasks.length == 1) return tasks.first.label;
    return '${tasks.first.label} (+${tasks.length - 1})';
  }

  String get statutLabel {
    switch (statut) {
      case InterventionStatut.enCours: return 'En cours';
      case InterventionStatut.termine: return 'Terminé';
      case InterventionStatut.planifie: return 'Planifié';
      case InterventionStatut.enAttente: return 'En attente';
      case InterventionStatut.annule: return 'Annulé';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.millisecondsSinceEpoch,
      'heure': heure,
      'statutLabelDiagram': statutLabelDiagram,
      'vehiculeId': vehiculeId,
      'userId': userId,
      'mecanicienId': mecanicienId,
      'alerteId': alerteId,
      'vehiculeNom': vehiculeNom,
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'prixEstime': prixEstime,
      'statut': statut.index,
      'mecanicienNom': mecanicienNom,
      'noteClient': noteClient,
      'estPaye': estPaye,
      if (kilometrageCompteur != null) 'kilometrageCompteur': kilometrageCompteur,
    };
  }

  factory Intervention.fromMap(String id, Map<dynamic, dynamic> map) {
    final tasksRaw = map['tasks'] as List?;
    final List<InterventionTask> tasks = tasksRaw != null
        ? tasksRaw.map((e) => InterventionTask.fromMap(e as Map)).toList()
        : [];

    final dateVal = map['date'];
    DateTime dateObj;
    if (dateVal is int) {
      dateObj = DateTime.fromMillisecondsSinceEpoch(dateVal);
    } else {
      dateObj = DateTime.now();
    }

    return Intervention(
      id: id,
      date: dateObj,
      heure: map['heure'] as String? ?? '${dateObj.hour}:${dateObj.minute}',
      statutLabelDiagram: map['statutLabelDiagram'] as String? ?? '',
      vehiculeId: map['vehiculeId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      mecanicienId: map['mecanicienId'] as String?,
      alerteId: map['alerteId'] as String?,
      vehiculeNom: map['vehiculeNom'] as String? ?? '',
      tasks: tasks,
      prixEstime: (map['prixEstime'] as num?)?.toDouble() ?? 0,
      statut: InterventionStatut.values[(map['statut'] as num?)?.toInt() ?? 0],
      mecanicienNom: map['mecanicienNom'] as String?,
      noteClient: (map['noteClient'] as num?)?.toInt(),
      estPaye: map['estPaye'] as bool? ?? false,
      kilometrageCompteur: (map['kilometrageCompteur'] as num?)?.toInt(),
    );
  }
}
