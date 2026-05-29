import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/vehicle.dart';
import '../../models/carnet_entretien.dart';
import '../../services/ai_service.dart';
import '../../services/carnet_service.dart';

class AIDiagnosticScreen extends StatefulWidget {
  final Vehicle vehicle;

  const AIDiagnosticScreen({super.key, required this.vehicle});

  @override
  State<AIDiagnosticScreen> createState() => _AIDiagnosticScreenState();
}

class _AIDiagnosticScreenState extends State<AIDiagnosticScreen> {
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _report;

  Future<void> _pickImages() async {
    if (_images.length >= 10) return;
    
    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.take(10 - _images.length));
      });
    }
  }

  Future<void> _generateReport() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins une photo (moteur, pneus, etc.)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _report = null;
    });

    try {
      // 1. Get History
      final history = await CarnetService.vehicleCarnetStream(widget.vehicle.id).first;
      
      // 2. Convert images to bytes
      List<Uint8List> imageBytes = [];
      for (var xf in _images) {
        imageBytes.add(await xf.readAsBytes());
      }

      // 3. Call AI
      final result = await AIService.generateHealthReport(
        vehicle: widget.vehicle,
        history: history,
        images: imageBytes,
      );

      setState(() => _report = result);
    } catch (e) {
      setState(() => _report = "Erreur lors de l'analyse : $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Santé IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            const Text('Photos du véhicule (Max 10)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Prenez des photos du moteur, des pneus, ou du tableau de bord.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildImageGrid(),
            const SizedBox(height: 24),
            if (!_isLoading && _report == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generateReport,
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text('LANCER L\'ANALYSE IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('L\'IA analyse votre véhicule...', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            if (_report != null) _buildReportDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "L'IA va analyser l'historique de votre ${widget.vehicle.nomComplet} (${widget.vehicle.kilometrageActuel} km) et vos photos pour détecter des problèmes potentiels.",
              style: const TextStyle(fontSize: 13, color: Color(0xFF1976D2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _images.length < 10 ? _images.length + 1 : 10,
      itemBuilder: (context, index) {
        if (index == _images.length && _images.length < 10) {
          return GestureDetector(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
            ),
          );
        }
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_images[index].path, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image)),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: () => setState(() => _images.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        Row(
          children: [
            const Icon(Icons.assignment_turned_in_outlined, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Rapport de Santé IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() { _report = null; _images.clear(); }),
            )
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Text(_report!, style: const TextStyle(fontSize: 14, height: 1.5)),
        ),
        const SizedBox(height: 20),
        const Text(
          "Attention : Ce diagnostic est généré par une IA et ne remplace pas l'avis d'un mécanicien professionnel.",
          style: TextStyle(fontSize: 11, color: Colors.red, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
