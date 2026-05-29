class MileageEntry {
  final DateTime date;
  final int kilometrage;

  MileageEntry({
    required this.date,
    required this.kilometrage,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.millisecondsSinceEpoch,
      'kilometrage': kilometrage,
    };
  }

  factory MileageEntry.fromMap(Map<dynamic, dynamic> map) {
    return MileageEntry(
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      kilometrage: map['kilometrage'] as int,
    );
  }
}
