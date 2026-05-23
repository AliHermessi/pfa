import 'package:firebase_database/firebase_database.dart';

class AdminService {
  static final _db = FirebaseDatabase.instance.ref();

  /// Récupère le revenu total (somme de prixEstime) pour les interventions terminées et payées, par mois.
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
              final isPaid = interData['estPaye'] == true;
              final dateVal = interData['date'];
              
              bool isTermine = false;
              if (status is int) {
                isTermine = status == 1; // index of InterventionStatut.termine (enCours=0, termine=1)
              } else if (status != null) {
                final statusStr = status.toString();
                isTermine = statusStr == 'termine' || statusStr == '1';
              }
              
              if (isTermine && isPaid && dateVal != null) {
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
                    final price = double.tryParse(interData['prixEstime']?.toString() ?? '0') ?? 0.0;
                    revenues[date.month - 1] += price;
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
}
