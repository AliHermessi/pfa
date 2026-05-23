import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── REGISTER ────────────────────────────────────────────────────────────────
  static Future<void> register({
    required String email,
    required String password,
    required String nom,
    required String role, // 'user', 'mecanicien', 'admin'
    String? specialite,
    String? telephone,
  }) async {
    // 1. Créer le compte Firebase Auth
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    // 2. Mettre à jour le displayName
    await credential.user!.updateDisplayName(nom);

    // 3. Enregistrer dans la bonne collection selon le rôle
    if (role == 'mecanicien') {
      // Mécanicien → dans /mecaniciens avec isApproved: false
      await _db.child('mecaniciens/$uid').set({
        'id': uid,
        'nom': nom,
        'email': email,
        'specialite': specialite ?? '',
        'telephone': telephone ?? '',
        'role': 'mecanicien',
        'isApproved': false, // Doit être approuvé par l'admin
        'disponible': true,
        'note': 0.0,
        'nombreAvis': 0,
        'distanceKm': 0.0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      // User standard → dans /users
      await _db.child('users/$uid').set({
        'id': uid,
        'nom': nom,
        'email': email,
        'role': role, // 'user' ou 'admin'
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // ── LOGIN ───────────────────────────────────────────────────────────────────
  /// Retourne le rôle de l'utilisateur connecté.
  /// Pour les mécaniciens non approuvés, throw une exception.
  static Future<String> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    try {
      // On lance les deux recherches en parallèle pour gagner du temps
      final Future<DataSnapshot> userFuture = _db.child('users/$uid').get();
      final Future<DataSnapshot> mecaFuture = _db.child('mecaniciens/$uid').get();

      final results = await Future.wait([userFuture, mecaFuture]).timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('Délai d\'attente dépassé'),
      );

      final userSnap = results[0];
      final mecaSnap = results[1];

      // 1. Vérifier si c'est un utilisateur/admin
      if (userSnap.exists) {
        final data = userSnap.value;
        if (data is Map) {
          return data['role'] as String? ?? 'user';
        }
      }

      // 2. Vérifier si c'est un mécanicien
      if (mecaSnap.exists) {
        final data = mecaSnap.value;
        if (data is Map) {
          final isApproved = data['isApproved'] as bool? ?? false;
          if (!isApproved) {
            await _auth.signOut();
            throw Exception(
                'Votre compte mécanicien est en attente d\'approbation par l\'administrateur.');
          }
          return 'mecanicien';
        }
      }
    } catch (e) {
      print('AuthService: Erreur ou timeout lors de la récupération du rôle : $e');
    }

    // Fallback (pas dans la DB → user normal)
    return 'user';
  }

  // ── LOGOUT ──────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ── GET CURRENT ROLE ────────────────────────────────────────────────────────
  static Future<String> getCurrentRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'none';

    try {
      // Vérifier user/admin d'abord
      final userSnap = await _db.child('users/$uid').get();
      if (userSnap.exists) {
        final data = userSnap.value;
        if (data is Map) {
          return data['role'] as String? ?? 'user';
        }
      }

      // Vérifier mécanicien
      final mecaSnap = await _db.child('mecaniciens/$uid').get();
      if (mecaSnap.exists) {
        final data = mecaSnap.value;
        if (data is Map) {
          final isApproved = data['isApproved'] as bool? ?? false;
          return isApproved ? 'mecanicien' : 'mecanicien_pending';
        }
      }
    } catch (e) {
      print('AuthService: Erreur getCurrentRole : $e');
    }

    return 'user';
  }
}
