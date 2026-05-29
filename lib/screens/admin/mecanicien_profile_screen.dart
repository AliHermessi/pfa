import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/mecanicien.dart';
import '../../services/admin_service.dart';
import 'package:intl/intl.dart';

class MecanicienProfileScreen extends StatefulWidget {
  final Mecanicien mecanicien;

  const MecanicienProfileScreen({super.key, required this.mecanicien});

  @override
  State<MecanicienProfileScreen> createState() => _MecanicienProfileScreenState();
}

class _MecanicienProfileScreenState extends State<MecanicienProfileScreen> {
  late bool _isApproved;

  @override
  void initState() {
    super.initState();
    _isApproved = widget.mecanicien.isApproved;
  }

  Future<void> _approve() async {
    await FirebaseDatabase.instance.ref('mecaniciens/${widget.mecanicien.id}').update({
      'isApproved': true,
      'statutCompte': 'actif',
    });
    setState(() => _isApproved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.mecanicien.nom} a été approuvé'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _reject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer le refus'),
        content: Text("Voulez-vous vraiment refuser et supprimer le profil de ${widget.mecanicien.nom} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Refuser', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseDatabase.instance.ref('mecaniciens/${widget.mecanicien.id}').remove();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Le profil de ${widget.mecanicien.nom} a été supprimé'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Détails du Mécanicien', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(),
            _buildStatusCard(),
            if (!_isApproved) _buildActionButtons(),
            _buildDetailsSection(),
            if (widget.mecanicien.latitude != null && widget.mecanicien.longitude != null) 
              _buildLocationMap(),
            _buildInterventionsSection(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Center(
              child: Text(widget.mecanicien.initiales, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.mecanicien.nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.build_circle_outlined, size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 4),
                    Text(widget.mecanicien.specialite, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
                    const SizedBox(width: 4),
                    Text('${widget.mecanicien.note.toStringAsFixed(1)} (${widget.mecanicien.nombreAvis} avis)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isApproved ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isApproved ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            _isApproved ? Icons.verified_user_rounded : Icons.pending_rounded,
            color: _isApproved ? Colors.green.shade600 : Colors.orange.shade600,
          ),
          const SizedBox(width: 12),
          Text(
            _isApproved ? 'Compte Partenaire Activé' : 'En attente d\'approbation',
            style: TextStyle(
              color: _isApproved ? Colors.green.shade800 : Colors.orange.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Refuser', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _approve,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Approuver ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations Professionnelles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _buildInfoCard(Icons.business_rounded, 'Nom du Garage', widget.mecanicien.nomGarage.isEmpty ? 'Non renseigné' : widget.mecanicien.nomGarage),
          const SizedBox(height: 12),
          _buildInfoCard(Icons.location_on_rounded, 'Adresse Physique', widget.mecanicien.adresseGarage.isEmpty ? 'Non renseignée' : widget.mecanicien.adresseGarage),
          const SizedBox(height: 12),
          _buildInfoCard(Icons.email_rounded, 'Contact Email', widget.mecanicien.email),
          const SizedBox(height: 12),
          _buildInfoCard(Icons.phone_rounded, 'Numéro Téléphone', widget.mecanicien.telephone),
          const SizedBox(height: 12),
          _buildInfoCard(Icons.access_time_filled_rounded, 'Horaires', '${widget.mecanicien.heuresDebut}h - ${widget.mecanicien.heuresFin}h'),
        ],
      ),
    );
  }

  Widget _buildLocationMap() {
    final pos = LatLng(widget.mecanicien.latitude!, widget.mecanicien.longitude!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('Localisation du Garage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ),
        Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: pos,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.vroomlog.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pos,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activités Récentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: AdminService.getInterventionsForUser(widget.mecanicien.id, true),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyInterventions();
              }
              return Column(
                children: snapshot.data!.map((inter) => _InterventionCard(intervention: inter)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInterventions() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Aucun historique d\'intervention', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _InterventionCard extends StatelessWidget {
  final Map<String, dynamic> intervention;
  const _InterventionCard({required this.intervention});

  @override
  Widget build(BuildContext context) {
    final dateVal = intervention['date'];
    String dateStr = 'Date inconnue';
    if (dateVal != null) {
      DateTime? dt;
      if (dateVal is int) dt = DateTime.fromMillisecondsSinceEpoch(dateVal);
      else if (dateVal is String) dt = DateTime.tryParse(dateVal);
      if (dt != null) dateStr = DateFormat('dd MMM yyyy à HH:mm').format(dt);
    }

    final isTermine = intervention['statut'] == 1 || intervention['statut'].toString() == 'termine';

    return GestureDetector(
      onTap: () => _showInterventionDetails(context, intervention),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isTermine ? Colors.green : Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isTermine ? Icons.check_circle_outline : Icons.pending_outlined, color: isTermine ? Colors.green : Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(intervention['titre'] ?? 'Intervention', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${intervention['prixEstime'] ?? 0} DT', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                const Text('Détails', style: TextStyle(fontSize: 10, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInterventionDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Détails de l\'intervention', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 20),
            _detailItem(Icons.label_important_outline, 'Titre', data['titre'] ?? 'N/A'),
            _detailItem(Icons.description_outlined, 'Description', data['description'] ?? 'Pas de description'),
            _detailItem(Icons.attach_money_outlined, 'Prix', '${data['prixEstime'] ?? 0} DT'),
            _detailItem(Icons.info_outline, 'Statut', data['statut'] == 1 ? 'Terminé' : 'En cours'),
            _detailItem(Icons.payment_outlined, 'Paiement', data['estPaye'] == true ? 'Payé' : 'Non payé'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Fermer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
