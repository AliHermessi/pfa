enum NotificationGravite { info, avertissement, alerte }

class AppNotification {
  final String id;
  final String userId;
  final String titre;
  final String message;
  final DateTime dateEnvoi;
  final bool estLu;
  final NotificationGravite gravite;
  
  final String? interventionId;
  final String? alerteId;

  AppNotification({
    required this.id,
    required this.userId,
    required this.titre,
    required this.message,
    required this.dateEnvoi,
    this.estLu = false,
    this.gravite = NotificationGravite.info,
    this.interventionId,
    this.alerteId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'titre': titre,
      'message': message,
      'dateEnvoi': dateEnvoi.millisecondsSinceEpoch,
      'estLu': estLu,
      'gravite': gravite.index,
      if (interventionId != null) 'interventionId': interventionId,
      if (alerteId != null) 'alerteId': alerteId,
    };
  }

  factory AppNotification.fromMap(String id, Map<dynamic, dynamic> map) {
    return AppNotification(
      id: id,
      userId: map['userId'] as String? ?? '',
      titre: map['titre'] as String? ?? '',
      message: map['message'] as String? ?? '',
      dateEnvoi: DateTime.fromMillisecondsSinceEpoch(
          (map['dateEnvoi'] ?? map['date'] as num?)?.toInt() ?? 0),
      estLu: map['estLu'] ?? map['lue'] as bool? ?? false,
      gravite: NotificationGravite.values[(map['gravite'] as num?)?.toInt() ?? 0],
      interventionId: map['interventionId'] as String?,
      alerteId: map['alerteId'] as String?,
    );
  }
}
