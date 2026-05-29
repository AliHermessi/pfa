import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/mecanicien.dart';
import '../../models/review.dart';
import '../../services/rating_service.dart';
import '../widgets/rating_dialog.dart';
import 'intervention_form_screen.dart';

class MecanicienDetailsScreen extends StatelessWidget {
  final Mecanicien mecanicien;

  const MecanicienDetailsScreen({super.key, required this.mecanicien});

  void _showRatingDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => RatingDialog(mecanicienNom: mecanicien.nom),
    );

    if (result != null && context.mounted) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await RatingService.submitRating(
        mecanicienId: mecanicien.id,
        userId: userId,
        note: result['rating'],
        commentaire: result['comment'],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Merci pour votre avis !'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('Profil Mécanicien', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 32, thickness: 1, indent: 20, endIndent: 20),
            _buildInfoSection(),
            const Divider(height: 32, thickness: 1, indent: 20, endIndent: 20),
            _buildRatingSection(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Hero(
            tag: 'avatar-${mecanicien.id}',
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF1976D2),
              child: Text(
                mecanicien.initiales,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(mecanicien.nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(mecanicien.specialite, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: mecanicien.disponible ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: mecanicien.disponible ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  mecanicien.disponible ? 'Disponible' : 'Occupé',
                  style: TextStyle(
                    color: mecanicien.disponible ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${mecanicien.distanceKm} km', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('À propos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.storefront_outlined, 'Garage', mecanicien.nomGarage),
          _buildInfoRow(Icons.location_on_outlined, 'Adresse', mecanicien.adresseGarage),
          _buildInfoRow(Icons.access_time, 'Horaires', '${mecanicien.heuresDebut}h - ${mecanicien.heuresFin}h'),
          _buildInfoRow(Icons.phone_outlined, 'Téléphone', mecanicien.telephone),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1976D2), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: RatingService.getMecanicienReviews(mecanicien.id),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? [];
        final avgNote = reviews.isEmpty ? 0.0 : reviews.map((r) => r.note).reduce((a, b) => a + b) / reviews.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Avis et notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Column(
                    children: [
                      Text(avgNote.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < avgNote.floor() ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFFB300),
                          size: 16,
                        )),
                      ),
                      const SizedBox(height: 4),
                      Text('${reviews.length} avis', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      children: List.generate(5, (index) {
                        int star = 5 - index;
                        int count = reviews.where((r) => r.note == star).length;
                        double percent = reviews.isEmpty ? 0 : count / reviews.length;
                        return _buildRatingBar(star, percent);
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (reviews.isNotEmpty) ...[
                const Text('Derniers avis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...reviews.take(3).map((r) => _ReviewItem(review: r)),
                const SizedBox(height: 16),
              ],
              const Text('Notez ce mécanicien', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Text('Partagez votre avis avec les autres utilisateurs.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(Icons.star_border_rounded, size: 42, color: Colors.grey.shade300),
                  onPressed: () => _showRatingDialog(context),
                )),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildRatingBar(int star, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$star', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.grey.shade100,
                color: const Color(0xFF1976D2),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InterventionFormScreen(initialMecanicien: mecanicien)),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('PRENDRE RENDEZ-VOUS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final Review review;
  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(5, (i) => Icon(
                  i < review.note ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFB300),
                  size: 12,
                )),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd MMM yyyy').format(review.date),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          if (review.commentaire != null && review.commentaire!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(review.commentaire!, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
