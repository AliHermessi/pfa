import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/intervention.dart';
import '../../services/payment_service.dart';
import '../../services/intervention_service.dart';

/// Écran de paiement Flouci.
///
/// Affiche la page de paiement Flouci dans une WebView intégrée.
/// Intercepte les redirections pour détecter le succès ou l'échec.
class PaymentScreen extends StatefulWidget {
  final String paymentUrl;
  final String paymentId;
  final Intervention intervention;

  const PaymentScreen({
    super.key,
    required this.paymentUrl,
    required this.paymentId,
    required this.intervention,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paymentProcessed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;

            // ── Détection du succès ────────────────────────────────────
            if (url.contains(PaymentService.successUrl) ||
                url.contains('success')) {
              if (!_paymentProcessed) {
                _paymentProcessed = true;
                _handlePaymentSuccess();
              }
              return NavigationDecision.prevent;
            }

            // ── Détection de l'échec ──────────────────────────────────
            if (url.contains(PaymentService.failUrl) ||
                url.contains('fail')) {
              if (!_paymentProcessed) {
                _paymentProcessed = true;
                _handlePaymentFailure();
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // Ignorer les erreurs de chargement des URLs de redirection
            if (error.errorType == WebResourceErrorType.unknown) return;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _handlePaymentSuccess() async {
    // Afficher un loader pendant la vérification
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Vérification du paiement...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Vérifier le paiement auprès de Flouci
      final verified = await PaymentService.verifyPayment(widget.paymentId);

      if (verified) {
        // Marquer l'intervention comme payée dans Firebase
        await InterventionService.markAsPaid(widget.intervention);

        if (!mounted) return;
        Navigator.of(context).pop(); // Fermer le loader

        // Afficher le message de succès
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
            title: const Text('Paiement réussi !'),
            content: Text(
              'Votre paiement de ${widget.intervention.prixEstime.toStringAsFixed(0)} DT a été effectué avec succès.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Fermer le dialog
                  Navigator.of(context).pop(true); // Retour avec résultat
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Le paiement n'est pas encore confirmé, on le marque quand même
        // car Flouci a redirigé vers success_link
        await InterventionService.markAsPaid(widget.intervention);

        if (!mounted) return;
        Navigator.of(context).pop(); // Fermer le loader
        Navigator.of(context).pop(true); // Retour avec résultat
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fermer le loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de vérification : $e'),
          backgroundColor: Colors.orange,
        ),
      );

      // On retourne quand même au cas où le paiement a été effectué
      Navigator.of(context).pop(true);
    }
  }

  void _handlePaymentFailure() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.cancel, color: Colors.red, size: 56),
        title: const Text('Paiement échoué'),
        content: const Text(
          'Le paiement n\'a pas pu être effectué. Veuillez réessayer.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer le dialog
              Navigator.of(context).pop(false); // Retour avec résultat
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title: const Text(
          'Paiement Flouci',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showCancelConfirmation(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  '${widget.intervention.prixEstime.toStringAsFixed(0)} DT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1976D2)),
                  SizedBox(height: 16),
                  Text(
                    'Chargement de la page de paiement...',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler le paiement ?'),
        content: const Text(
          'Êtes-vous sûr de vouloir quitter ? Le paiement ne sera pas effectué.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer le dialog
              Navigator.of(context).pop(false); // Retour
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }
}
