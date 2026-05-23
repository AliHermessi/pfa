import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

/// Service de localisation GPS pour les mécaniciens.
/// Publie la position en temps réel dans Firebase sous mecaniciens/{uid}/
class LocationService {
  static StreamSubscription<Position>? _positionSubscription;
  static bool _isTracking = false;

  // ── Paramètres de tracking ─────────────────────────────────────────────────
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 30, // Mise à jour si déplacement > 30 mètres
  );

  // ── Démarrer le tracking (appelé par le mécanicien connecté) ───────────────
  static Future<bool> startTracking(String mecaId) async {
    if (_isTracking) return true;

    // 1. Vérifier le service GPS activé
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // 2. Vérifier / demander la permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    _isTracking = true;

    // 3. Publier la position initiale immédiatement
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
      await _publishPosition(mecaId, pos);
    } catch (_) {}

    // 4. S'abonner aux mises à jour de position
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(
      (Position pos) => _publishPosition(mecaId, pos),
      onError: (_) {},
    );

    return true;
  }

  // ── Arrêter le tracking ────────────────────────────────────────────────────
  static Future<void> stopTracking(String mecaId) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;

    // Ne pas effacer la position GPS (pour garder la dernière connue),
    // mais marquer la date de dernière vue à null pour signaler la déconnexion.
    try {
      await FirebaseDatabase.instance
          .ref('mecaniciens/$mecaId')
          .update({'lastSeen': null});
    } catch (_) {}
  }

  // ── Publier la position dans Firebase ─────────────────────────────────────
  static Future<void> _publishPosition(String mecaId, Position pos) async {
    await FirebaseDatabase.instance.ref('mecaniciens/$mecaId').update({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static bool get isTracking => _isTracking;
}
