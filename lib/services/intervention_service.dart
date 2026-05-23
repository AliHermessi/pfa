import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/intervention.dart';
import 'planning_service.dart';
import 'notification_service.dart';

class InterventionService {
  // ✅ FIX : utiliser uniquement FirebaseDatabase.instance
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── Référence pour l'utilisateur connecté ─────────────────────────────────
  static DatabaseReference _userInterventionsRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    return _db.child('interventions/$uid');
  }

  // ── Stream pour l'utilisateur (ses propres interventions) ──────────────────
  static Stream<List<Intervention>> interventionsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db.child('interventions/$uid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      if (data is Map) {
        final list = data.entries
            .where((e) => e.value is Map)
            .map((e) => Intervention.fromMap(e.key as String, e.value as Map))
            .toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      }
      return [];
    });
  }

  // ── Stream pour le mécanicien (les interventions qui lui sont assignées) ───
  static Stream<List<Intervention>> mecanicInterventionsStream(
      String mecanicId) {
    return _db.child('mecanic_interventions/$mecanicId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .where((e) => e.value is Map)
          .map((e) => Intervention.fromMap(e.key as String, e.value as Map))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // ── Ajouter une intervention (User -> Request) ────────────────────────────
  static Future<void> addIntervention(Intervention intervention) async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) throw Exception('Utilisateur non connecté');

    final interventionRef = _db.child('interventions/$userUid').push();
    final String interventionId = interventionRef.key!;

    final data = intervention.toMap();
    data['id'] = interventionId;

    // 1. Enregistrer dans le noeud de l'utilisateur
    await interventionRef.set(data);

    // 2. Si un mécanicien est spécifié, enregistrer aussi dans son noeud
    if (intervention.mecanicienId != null) {
      await _db
          .child(
              'mecanic_interventions/${intervention.mecanicienId}/$interventionId')
          .set(data);
    }
  }

  // ── Accepter une intervention (Mécanicien) ────────────────────────────────
  static Future<void> acceptIntervention(Intervention intervention) async {
    await _updateStatusEverywhere(intervention, InterventionStatut.planifie);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == intervention.mecanicienId) {
      final nomMec = intervention.mecanicienNom ?? 'Un mécanicien';
      await NotificationService.sendNotification(
        userId: intervention.userId,
        titre: 'Demande acceptée',
        message:
            '$nomMec a accepté votre demande pour ${intervention.vehiculeNom}.',
        interventionId: intervention.id,
      );
    }
  }

  // ── Annuler une intervention (Mécanicien ou User) ─────────────────────────
  static Future<void> cancelIntervention(Intervention intervention) async {
    await _updateStatusEverywhere(intervention, InterventionStatut.annule);
    if (intervention.mecanicienId != null) {
      await PlanningService.libererCreneau(
          intervention.mecanicienId!, intervention.date);
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == intervention.mecanicienId) {
      final nomMec = intervention.mecanicienNom ?? 'Le mécanicien';
      await NotificationService.sendNotification(
        userId: intervention.userId,
        titre: 'Demande refusée',
        message:
            '$nomMec a refusé votre demande pour ${intervention.vehiculeNom}. Veuillez soumettre une nouvelle demande à un autre mécanicien.',
        interventionId: intervention.id,
      );
    }
  }

  // ── Marquer comme En Cours ──────────────────────────────────────────────────
  static Future<void> startIntervention(Intervention intervention) async {
    await _updateStatusEverywhere(intervention, InterventionStatut.enCours);
  }

  // ── Marquer comme terminé ─────────────────────────────────────────────────
  static Future<void> completeIntervention(Intervention intervention,
      {double? finalPrice}) async {
    final Map<String, dynamic> updates = {};
    updates['interventions/${intervention.userId}/${intervention.id}/statut'] =
        InterventionStatut.termine.index;
    if (intervention.mecanicienId != null) {
      updates['mecanic_interventions/${intervention.mecanicienId}/${intervention.id}/statut'] =
          InterventionStatut.termine.index;
    }

    if (finalPrice != null) {
      updates['interventions/${intervention.userId}/${intervention.id}/prixEstime'] =
          finalPrice;
      if (intervention.mecanicienId != null) {
        updates['mecanic_interventions/${intervention.mecanicienId}/${intervention.id}/prixEstime'] =
            finalPrice;
      }
    }

    await _db.update(updates);
  }

  // ── Mettre à jour le statut partout ──────────────────────────────────────
  static Future<void> _updateStatusEverywhere(
      Intervention intervention, InterventionStatut status) async {
    final Map<String, dynamic> updates = {};

    // Chemin utilisateur
    updates['interventions/${intervention.userId}/${intervention.id}/statut'] =
        status.index;

    // Chemin mécanicien
    if (intervention.mecanicienId != null) {
      updates['mecanic_interventions/${intervention.mecanicienId}/${intervention.id}/statut'] =
          status.index;
    }

    await _db.update(updates);
  }

  // ── Supprimer une intervention ────────────────────────────────────────────
  static Future<void> deleteIntervention(Intervention intervention) async {
    await _db
        .child('interventions/${intervention.userId}/${intervention.id}')
        .remove();
    if (intervention.mecanicienId != null) {
      await _db
          .child(
              'mecanic_interventions/${intervention.mecanicienId}/${intervention.id}')
          .remove();
      // Libérer le créneau si l'intervention n'était pas terminée
      if (intervention.statut != InterventionStatut.termine) {
        await PlanningService.libererCreneau(
            intervention.mecanicienId!, intervention.date);
      }
    }
  }

  // ── Marquer une intervention comme payée ───────────────────────────────────
  static Future<void> markAsPaid(Intervention intervention) async {
    final Map<String, dynamic> updates = {};

    updates['interventions/${intervention.userId}/${intervention.id}/estPaye'] =
        true;

    if (intervention.mecanicienId != null) {
      updates['mecanic_interventions/${intervention.mecanicienId}/${intervention.id}/estPaye'] =
          true;
    }

    await _db.update(updates);
  }
}
