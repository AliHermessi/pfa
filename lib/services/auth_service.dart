import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/utilisateur.dart';
import '../models/client.dart';
import '../models/mecanicien.dart';
import '../models/administrateur.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── REGISTER ────────────────────────────────────────────────────────────────
  static Future<void> register({
    required String email,
    required String password,
    required String nom,
    required String role, // 'user', 'mecanicien', 'admin'
    String? telephone,
    // Diagram fields
    String? adresse, // for Client
    String? nomGarage, // for Mecanicien
    String? adresseGarage, // for Mecanicien
    String? specialite, // Kept as extra
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    await credential.user!.updateDisplayName(nom);

    if (role == 'mecanicien') {
      await _db.child('mecaniciens/$uid').set({
        'id': uid,
        'nom': nom,
        'email': email,
        'telephone': telephone ?? '',
        'role': 'mecanicien',
        'nomGarage': nomGarage ?? '',
        'adresseGarage': adresseGarage ?? '',
        'statutCompte': 'en_attente', 
        'isApproved': false,
        'specialite': specialite ?? '',
        'disponible': true,
        'note': 0.0,
        'nombreAvis': 0,
        'distanceKm': 0.0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await _db.child('users/$uid').set({
        'id': uid,
        'nom': nom,
        'email': email,
        'telephone': telephone ?? '',
        'role': role,
        'adresse': adresse ?? '',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Tente de connecter l'utilisateur et retourne son rôle.
  /// Si le compte est un mécanicien en attente, retourne 'pending_mecanicien'.
  static Future<String> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final user = await getUser(uid);
    
    if (user == null) {
      throw Exception("Données utilisateur introuvables.");
    }

    // Vérification spécifique pour l'approbation du mécanicien
    if (user is Mecanicien && !user.isApproved) {
      return 'pending_mecanicien';
    }
    
    return user.role;
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static Future<Utilisateur?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return await getUser(uid);
  }

  static Future<Utilisateur?> getUser(String uid) async {
    try {
      // 1. Chercher dans 'users' (Clients et Admins)
      final userSnap = await _db.child('users/$uid').get();
      if (userSnap.exists) {
        final data = Map<String, dynamic>.from(userSnap.value as Map);
        if (data['role'] == 'admin') {
          return Administrateur.fromMap(uid, data);
        } else {
          return Client.fromMap(uid, data);
        }
      }

      // 2. Chercher dans 'mecaniciens'
      final mecaSnap = await _db.child('mecaniciens/$uid').get();
      if (mecaSnap.exists) {
        final data = Map<String, dynamic>.from(mecaSnap.value as Map);
        return Mecanicien.fromMap(uid, data);
      }
    } catch (e) {
      print('AuthService: Erreur getUser : $e');
    }
    return null;
  }

  static Future<String> getCurrentRole() async {
    final user = await getCurrentUser();
    if (user == null) return 'none';
    
    if (user is Mecanicien && !user.isApproved) {
      return 'pending_mecanicien';
    }
    
    return user.role;
  }

  // ── UPLOAD PHOTO ───────────────────────────────────────────────────────────
  static Future<String?> uploadProfilePhoto(File imageFile) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final ref = _storage.ref().child('profile_photos').child('$uid.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  // ── UPDATE PROFILE ─────────────────────────────────────────────────────────
  static Future<void> updateProfile({
    required String nom,
    required String telephone,
    String? photoUrl,
    String? adresse,
    String? nomGarage,
    String? adresseGarage,
    double? latitude,
    double? longitude,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final role = await getCurrentRole();

    if (nom.isNotEmpty) await user.updateDisplayName(nom);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);

    final Map<String, dynamic> updates = {
      'nom': nom,
      'telephone': telephone,
    };
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (adresse != null) updates['adresse'] = adresse;
    if (nomGarage != null) updates['nomGarage'] = nomGarage;
    if (adresseGarage != null) updates['adresseGarage'] = adresseGarage;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;

    if (role == 'mecanicien' || role == 'pending_mecanicien') {
      await _db.child('mecaniciens/$uid').update(updates);
    } else {
      await _db.child('users/$uid').update(updates);
    }
  }
}
