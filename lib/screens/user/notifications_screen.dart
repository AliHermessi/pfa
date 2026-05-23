import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/app_notification.dart';
import '../../models/intervention.dart';
import '../../services/notification_service.dart';
import '../chat_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title:
            const Text('Notifications', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Tout marquer comme lu',
            onPressed: () {
              NotificationService.markAllAsRead();
            },
          )
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.getUserNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'Aucune notification',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _NotificationCard(notification: notif);
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'À l\'instant';
        return 'Il y a ${diff.inMinutes} min';
      }
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Hier';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  void _handleNotificationTap(BuildContext context) async {
    // 1. Mark as read if not already
    if (!notification.lue) {
      NotificationService.markAsRead(notification.id);
    }

    final interventionId = notification.interventionId;
    if (interventionId == null || interventionId.isEmpty) {
      return;
    }

    // 2. Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final userUid = FirebaseAuth.instance.currentUser?.uid;
      if (userUid != null) {
        // Try fetching from user's interventions node first
        var snapshot = await FirebaseDatabase.instance
            .ref()
            .child('interventions/$userUid/$interventionId')
            .get();

        // If not found, try fetching from mechanic's interventions node
        if (!snapshot.exists) {
          snapshot = await FirebaseDatabase.instance
              .ref()
              .child('mecanic_interventions/$userUid/$interventionId')
              .get();
        }

        // Close loading dialog safely
        if (context.mounted) {
          Navigator.pop(context);
        }

        if (snapshot.exists && snapshot.value != null) {
          final map = snapshot.value as Map<dynamic, dynamic>;
          final intervention = Intervention.fromMap(snapshot.key!, map);

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(intervention: intervention),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Intervention introuvable ou supprimée'),
              ),
            );
          }
        }
      } else {
        if (context.mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      // Close loading dialog safely
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleNotificationTap(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.lue ? Colors.white : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                notification.lue ? Colors.grey.shade200 : Colors.blue.shade200,
          ),
          boxShadow: [
            if (!notification.lue)
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: notification.lue
                    ? Colors.grey.shade100
                    : Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                notification.titre.toLowerCase().contains('refus')
                    ? Icons.cancel_outlined
                    : notification.titre.toLowerCase().contains('accept')
                        ? Icons.check_circle_outline
                        : Icons.notifications_none,
                color: notification.lue
                    ? Colors.grey.shade600
                    : notification.titre.toLowerCase().contains('refus')
                        ? Colors.red
                        : Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.titre,
                          style: TextStyle(
                            fontWeight: notification.lue
                                ? FontWeight.w500
                                : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(notification.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: notification.lue
                              ? Colors.grey
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: notification.lue
                          ? Colors.grey.shade700
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.lue) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
