import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../models/app_notification.dart';
import '../../models/intervention.dart';
import '../../services/notification_service.dart';
import '../chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationGravite? initialFilter; 
  const NotificationsScreen({super.key, this.initialFilter});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationGravite? _activeFilter;

  @override
  void initState() {
    super.initState();
    // Use the initial filter if provided (e.g., from the Dashboard alert card)
    _activeFilter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Tout marquer comme lu',
            onPressed: () => NotificationService.markAllAsRead(),
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: NotificationService.getUserNotificationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data ?? [];
                
                // Filter the notifications based on gravity
                final filtered = _activeFilter == null 
                    ? all 
                    : all.where((n) => n.gravite == _activeFilter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Aucune notification', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _NotificationCard(notification: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _filterChip('Tous', null, Colors.blue),
            _filterChip('Alertes', NotificationGravite.alerte, Colors.red),
            _filterChip('Avertissements', NotificationGravite.avertissement, Colors.orange),
            _filterChip('Infos', NotificationGravite.info, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, NotificationGravite? gravite, Color color) {
    final isActive = _activeFilter == gravite;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = gravite),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    Color iconColor = Colors.blue;
    IconData icon = Icons.notifications_none;

    if (notification.gravite == NotificationGravite.alerte) {
      iconColor = Colors.red;
      icon = Icons.warning_amber_rounded;
    } else if (notification.gravite == NotificationGravite.avertissement) {
      iconColor = Colors.orange;
      icon = Icons.priority_high_rounded;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: notification.estLu ? Colors.grey.shade200 : iconColor.withOpacity(0.3)),
      ),
      color: notification.estLu ? Colors.white : iconColor.withOpacity(0.05),
      child: ListTile(
        onTap: () => _handleTap(context),
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(notification.titre, style: TextStyle(fontWeight: notification.estLu ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(DateFormat('dd/MM/yy HH:mm').format(notification.dateEnvoi), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        trailing: !notification.estLu ? const Icon(Icons.fiber_manual_record, color: Colors.blue, size: 12) : null,
      ),
    );
  }

  void _handleTap(BuildContext context) async {
    if (!notification.estLu) {
      NotificationService.markAsRead(notification.id);
    }
    if (notification.interventionId != null && notification.interventionId!.isNotEmpty) {
       showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final userUid = FirebaseAuth.instance.currentUser?.uid;
        final snapshot = await FirebaseDatabase.instance.ref().child('interventions/$userUid/${notification.interventionId}').get();
        if (context.mounted) Navigator.pop(context);
        if (snapshot.exists) {
          final intervention = Intervention.fromMap(snapshot.key!, snapshot.value as Map);
          if (context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(intervention: intervention)));
          }
        }
      } catch (_) {
        if (context.mounted) Navigator.pop(context);
      }
    }
  }
}
