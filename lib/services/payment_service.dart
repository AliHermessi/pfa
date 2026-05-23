import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service de paiement Flouci pour la Tunisie.
///
/// ⚠️ IMPORTANT : Remplacez les clés ci-dessous par vos propres clés
/// obtenues depuis le dashboard Flouci (https://flouci.com).
class PaymentService {
  // ── Clés d'API Flouci (à remplacer par vos clés) ──────────────────────────
  static const String _publicKey = 'YOUR_PUBLIC_KEY';
  static const String _secretKey = 'YOUR_SECRET_KEY';

  static const String _baseUrl = 'https://developers.flouci.com/api';

  // URLs de redirection après paiement
  static const String successUrl = 'https://vroomlog.app/payment/success';
  static const String failUrl = 'https://vroomlog.app/payment/fail';

  /// Génère un paiement Flouci.
  ///
  /// [amountInDT] : montant en Dinars Tunisiens (sera converti en millimes).
  /// Retourne un [Map] contenant `paymentId` et `link` (URL de paiement).
  static Future<Map<String, String>> generatePayment({
    required double amountInDT,
    required String trackingId,
  }) async {
    // Convertir DT en millimes (1 DT = 1000 millimes)
    final int amountMillimes = (amountInDT * 1000).toInt();

    final uri = Uri.parse('$_baseUrl/generate_payment');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'apppublic': _publicKey,
        'appsecret': _secretKey,
      },
      body: jsonEncode({
        'app_token': _publicKey,
        'app_secret': _secretKey,
        'amount': amountMillimes.toString(),
        'accept_card': 'true',
        'session_timeout_secs': 1200,
        'success_link': successUrl,
        'fail_link': failUrl,
        'developer_tracking_id': trackingId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['result'] != null && data['result']['link'] != null) {
        return {
          'paymentId': data['result']['payment_id']?.toString() ?? '',
          'link': data['result']['link'] as String,
        };
      } else {
        throw Exception('Réponse inattendue de Flouci: ${response.body}');
      }
    } else {
      throw Exception(
        'Erreur Flouci (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Vérifie le statut d'un paiement.
  ///
  /// [paymentId] : l'identifiant du paiement retourné par [generatePayment].
  /// Retourne `true` si le paiement a été validé avec succès.
  static Future<bool> verifyPayment(String paymentId) async {
    final uri = Uri.parse('$_baseUrl/verify_payment/$paymentId');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'apppublic': _publicKey,
        'appsecret': _secretKey,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final bool success = data['result']?['status'] == 'SUCCESS';
      return success;
    }
    return false;
  }
}
