import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'vehicle_service.dart';
import 'intervention_service.dart';
import 'carnet_service.dart';
import '../models/vehicle.dart';
import '../models/intervention.dart';
import '../models/app_notification.dart';

class ReminderService {
  static Future<void> checkAndGenerateReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    await _checkMileageReminders(uid);
    await _checkInterventionReminders(uid);
    await _checkHealthAlerts(uid);
  }

  static Future<void> _checkMileageReminders(String uid) async {
    final vehicles = await VehicleService.vehiclesStream().first;
    final now = DateTime.now();

    for (var v in vehicles) {
      final difference = now.difference(v.dernierMiseAJourKm).inDays;
      if (difference >= v.rappelKmJours) {
        await NotificationService.sendNotification(
          userId: uid,
          titre: 'Mise à jour du kilométrage',
          message: 'Il est temps de mettre à jour le kilométrage de votre ${v.nomComplet} pour un meilleur suivi.',
          gravite: NotificationGravite.info,
        );
      }
    }
  }

  static Future<void> _checkInterventionReminders(String uid) async {
    final interventions = await InterventionService.interventionsStream().first;
    final now = DateTime.now();

    for (var i in interventions) {
      if (i.statut == InterventionStatut.planifie) {
        final diff = i.date.difference(now);
        if (diff.inHours <= 24 && diff.inHours > 0) {
          await NotificationService.sendNotification(
            userId: uid,
            titre: 'Rappel Intervention',
            message: 'Votre rendez-vous pour ${i.vehiculeNom} est prévu dans moins de 24h (${i.typeLabel}).',
            gravite: NotificationGravite.info,
            interventionId: i.id,
          );
        }
      }
    }
  }

  static Future<void> _checkHealthAlerts(String uid) async {
    final vehicles = await VehicleService.vehiclesStream().first;
    final now = DateTime.now();

    for (var v in vehicles) {
      final carnet = await CarnetService.vehicleCarnetStream(v.id).first;
      if (carnet.isEmpty) continue;

      for (var entry in carnet) {
        final kmDiff = v.kilometrageActuel - entry.dernierKilometrageChangement;
        final daysDiff = now.difference(entry.dateChangement).inDays;

        // Thresholds as per requirements: 40k km or 3 years
        const maxKm = 40000;
        const maxDays = 3 * 365;

        final usureKm = kmDiff / maxKm;
        final usureTime = daysDiff / maxDays;
        final usureMax = usureKm > usureTime ? usureKm : usureTime;

        if (usureMax >= 1.0) {
          // Urgent Alert
          await NotificationService.sendNotification(
            userId: uid,
            titre: 'ALERTE : ${entry.nomComposantCustom}',
            message: 'La maintenance de ${entry.nomComposantCustom} sur votre ${v.nomComplet} est EXTRÊMEMENT urgente.',
            gravite: NotificationGravite.alerte,
          );
        } else if (usureMax >= 0.8) {
          // Close Warning
          await NotificationService.sendNotification(
            userId: uid,
            titre: 'Maintenance Proche : ${entry.nomComposantCustom}',
            message: 'Le composant ${entry.nomComposantCustom} de votre ${v.nomComplet} approche de sa limite de vie.',
            gravite: NotificationGravite.info,
          );
        }
      }
    }
  }
}
