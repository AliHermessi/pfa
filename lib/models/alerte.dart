import 'app_notification.dart';

class Alerte {
  final String id;
  final String descriptionPanne;
  final DateTime dateDetection;
  final NotificationGravite gravite;
  final bool estResolue;
  final String vehicleId;
  final String? rendezVousId;

  Alerte({
    required this.id,
    required this.descriptionPanne,
    required this.dateDetection,
    required this.gravite,
    required this.estResolue,
    required this.vehicleId,
    this.rendezVousId,
  });

  Map<String, dynamic> toMap() {
    return {
      'descriptionPanne': descriptionPanne,
      'dateDetection': dateDetection.millisecondsSinceEpoch,
      'gravite': gravite.index,
      'estResolue': estResolue,
      'vehicleId': vehicleId,
      'rendezVousId': rendezVousId,
    };
  }

  factory Alerte.fromMap(String id, Map<dynamic, dynamic> map) {
    return Alerte(
      id: id,
      descriptionPanne: map['descriptionPanne'] as String? ?? '',
      dateDetection: DateTime.fromMillisecondsSinceEpoch(
        (map['dateDetection'] as num?)?.toInt() ?? 0,
      ),
      gravite: NotificationGravite.values[(map['gravite'] as num?)?.toInt() ?? 0],
      estResolue: map['estResolue'] as bool? ?? false,
      vehicleId: map['vehicleId'] as String? ?? '',
      rendezVousId: map['rendezVousId'] as String?,
    );
  }
}
