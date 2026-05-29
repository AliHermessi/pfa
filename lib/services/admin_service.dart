import 'package:firebase_database/firebase_database.dart';

class AdminService {
  static final _db = FirebaseDatabase.instance.ref();

  /// Récupère le revenu total (10 DT par intervention terminée) par mois.
  /// Retourne une liste de 12 doubles (de Janvier à Décembre).
  static Future<List<double>> getMonthlyRevenue(int year) async {
    final snapshot = await _db.child('interventions').get();
    List<double> revenues = List.filled(12, 0.0);

    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((_, userInterventions) {
        if (userInterventions is Map) {
          userInterventions.forEach((_, interData) {
            if (interData is Map) {
              final status = interData['statut'];
              // final isPaid = interData['estPaye'] == true; // On peut garder ou pas selon si l'app prend les 10d seulement quand c'est payé
              final dateVal = interData['date'];
              
              bool isTermine = false;
              if (status is int) {
                isTermine = status == 1; // index of InterventionStatut.termine (enCours=0, termine=1)
              } else if (status != null) {
                final statusStr = status.toString();
                isTermine = statusStr == 'termine' || statusStr == '1';
              }
              
              if (isTermine && dateVal != null) {
                try {
                  DateTime? date;
                  if (dateVal is int) {
                    date = DateTime.fromMillisecondsSinceEpoch(dateVal);
                  } else {
                    final parsedInt = int.tryParse(dateVal.toString());
                    if (parsedInt != null) {
                      date = DateTime.fromMillisecondsSinceEpoch(parsedInt);
                    } else {
                      date = DateTime.parse(dateVal.toString());
                    }
                  }

                  if (date.year == year) {
                    // L'application prend 10 DT par intervention terminée
                    revenues[date.month - 1] += 10.0;
                  }
                } catch (_) {}
              }
            }
          });
        }
      });
    }
    return revenues;
  }

  /// Récupère le nombre total d'interventions par mois.
  /// Retourne une liste de 12 entiers (de Janvier à Décembre).
  static Future<List<int>> getMonthlyInterventionsCount(int year) async {
    final snapshot = await _db.child('interventions').get();
    List<int> counts = List.filled(12, 0);

    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((_, userInterventions) {
        if (userInterventions is Map) {
          userInterventions.forEach((_, interData) {
            if (interData is Map) {
              final dateVal = interData['date'];
              if (dateVal != null) {
                try {
                  DateTime? date;
                  if (dateVal is int) {
                    date = DateTime.fromMillisecondsSinceEpoch(dateVal);
                  } else {
                    final parsedInt = int.tryParse(dateVal.toString());
                    if (parsedInt != null) {
                      date = DateTime.fromMillisecondsSinceEpoch(parsedInt);
                    } else {
                      date = DateTime.parse(dateVal.toString());
                    }
                  }

                  if (date.year == year) {
                    counts[date.month - 1] += 1;
                  }
                } catch (_) {}
              }
            }
          });
        }
      });
    }
    return counts;
  }

  /// Récupère les top mécaniciens par nombre d'interventions affectées.
  static Future<Map<String, int>> getTopMechanics() async {
    final snapshot = await _db.child('interventions').get();
    Map<String, int> mecaCounts = {};

    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((_, userInterventions) {
        if (userInterventions is Map) {
          userInterventions.forEach((_, interData) {
            if (interData is Map) {
              final mecaId = interData['mecanicienId'];
              if (mecaId != null && mecaId.toString().isNotEmpty) {
                mecaCounts[mecaId.toString()] = (mecaCounts[mecaId.toString()] ?? 0) + 1;
              }
            }
          });
        }
      });
    }

    // Récupérer les noms des mécaniciens
    Map<String, int> topMecas = {};
    for (var mecaId in mecaCounts.keys) {
      final mSnapshot = await _db.child('mecaniciens/$mecaId/nom').get();
      final nom = mSnapshot.exists ? mSnapshot.value.toString() : 'Mécano $mecaId';
      topMecas[nom] = (topMecas[nom] ?? 0) + mecaCounts[mecaId]!;
    }

    // Trier
    var sortedEntries = topMecas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries.take(5));
  }
  
  /// Récupère toutes les données pour l'export.
  static Future<List<Map<String, dynamic>>> getAllInterventionsForExport() async {
    final snapshot = await _db.child('interventions').get();
    List<Map<String, dynamic>> result = [];
    
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((clientId, userInterventions) {
        if (userInterventions is Map) {
          userInterventions.forEach((interId, interData) {
            if (interData is Map) {
              result.add({
                'id': interId,
                'clientId': clientId,
                'titre': interData['titre'] ?? '',
                'date': interData['date'] ?? '',
                'statut': interData['statut'] ?? '',
                'prixEstime': interData['prixEstime'] ?? 0,
                'estPaye': interData['estPaye'] == true,
                'mecanicienId': interData['mecanicienId'] ?? '',
              });
            }
          });
        }
      });
    }
    return result;
  }

  /// Récupère les interventions d'un utilisateur spécifique (mécano ou client)
  static Future<List<Map<String, dynamic>>> getInterventionsForUser(String userId, bool isMecanicien) async {
    final snapshot = await _db.child('interventions').get();
    List<Map<String, dynamic>> result = [];
    
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((clientId, userInterventions) {
        if (userInterventions is Map) {
          userInterventions.forEach((interId, interData) {
            if (interData is Map) {
              bool match = false;
              if (isMecanicien) {
                match = interData['mecanicienId'] == userId;
              } else {
                match = clientId == userId;
              }

              if (match) {
                result.add({
                  'id': interId,
                  'clientId': clientId,
                  ...Map<String, dynamic>.from(interData),
                });
              }
            }
          });
        }
      });
    }
    // Trier par date décroissante
    result.sort((a, b) {
      final dateA = a['date']?.toString() ?? '';
      final dateB = b['date']?.toString() ?? '';
      return dateB.compareTo(dateA);
    });
    return result;
  }
}
