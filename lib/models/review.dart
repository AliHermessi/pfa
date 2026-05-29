class Review {
  final String id;
  final String userId;
  final int note;
  final DateTime date;
  final String? commentaire;

  Review({
    required this.id,
    required this.userId,
    required this.note,
    required this.date,
    this.commentaire,
  });

  factory Review.fromMap(String id, Map<dynamic, dynamic> map) {
    return Review(
      id: id,
      userId: map['userId'] as String? ?? '',
      note: (map['note'] as num?)?.toInt() ?? 0,
      date: DateTime.fromMillisecondsSinceEpoch((map['date'] as num?)?.toInt() ?? 0),
      commentaire: map['commentaire'] as String?,
    );
  }
}
