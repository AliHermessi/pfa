class AppNotification {
  final String id;
  final String userId;
  final String titre;
  final String message;
  final DateTime date;
  final bool lue;
  final String? interventionId;
  AppNotification({
    required this.id,
    required this.userId,
    required this.titre,
    required this.message,
    required this.date,
    this.lue = false,
    this.interventionId,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'titre': titre,
      'message': message,
      'date': date.millisecondsSinceEpoch,
      'lue': lue,
      if (interventionId != null) 'interventionId': interventionId,
    };
  }

  factory AppNotification.fromMap(String id, Map<dynamic, dynamic> map) {
    return AppNotification(
      id: id,
      userId: map['userId'] as String? ?? '',
      titre: map['titre'] as String? ?? '',
      message: map['message'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
          (map['date'] as num?)?.toInt() ?? 0),
      lue: map['lue'] as bool? ?? false,
      interventionId: map['interventionId'] as String?,
    );
  }
}
