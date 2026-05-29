import 'package:firebase_database/firebase_database.dart';
import '../models/facture.dart';

class FactureService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static Future<void> saveFacture(Facture facture) async {
    final ref = _db.child('factures/${facture.interventionId}');
    await ref.set(facture.toMap());
    
    // Also update intervention to link it if needed, 
    // though using interventionId as the key in 'factures' node is enough.
  }

  static Future<Facture?> getFacture(String interventionId) async {
    final snapshot = await _db.child('factures/$interventionId').get();
    if (snapshot.exists) {
      return Facture.fromMap(interventionId, snapshot.value as Map);
    }
    return null;
  }
}
