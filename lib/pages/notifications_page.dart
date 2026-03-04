// ============================================================
// notifications_page.dart
//
// Système de notifications complet côté client :
// - Widget cloche avec badge (nombre non lus)
// - Page liste des notifications temps réel
// - Icônes et couleurs selon type (réservation, commande, etc.)
// - Marquer comme lu / tout marquer
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WIDGET CLOCHE AVEC BADGE (à placer dans AppBar)
// Usage: NotificationBell()
// ══════════════════════════════════════════════════════════════════════════════

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  static const _primary = Color(0xFF9B4610);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<int>(
      stream: NotificationService.unreadCountStream(user.uid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_rounded, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsPage(),
                  ),
                );
              },
              tooltip: 'Notifications',
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAGE NOTIFICATIONS
// ══════════════════════════════════════════════════════════════════════════════

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Connectez-vous pour voir vos notifications')),
      );
    }

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => NotificationService.markAllAsRead(user.uid),
            child: const Text(
              'Tout lire',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ Query directe sans passer par le service (pour debug)
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune notification',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vos notifications apparaîtront ici',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _NotificationTile(
                id: doc.id,
                data: data,
              );
            },
          );
        },
      ),
    );
  }
}

// ── Tuile notification ────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const _NotificationTile({required this.id, required this.data});

  static const _primary = Color(0xFF9B4610);

  // ✅ Navigation selon le type de notification
  void _handleTap(BuildContext context) {
    if (!(data['read'] as bool? ?? false)) {
      NotificationService.markAsRead(id);
    }
    final type = data['type'] ?? '';
    final commandeId = data['commandeId'] as String?;

    switch (type) {
      case 'commande':
        if (commandeId != null && commandeId.isNotEmpty) {
          _showNotifDetail(context, Icons.room_service_rounded, Colors.orange);
        }
        break;
      case 'message':
      case 'nouveau_message':
        // Naviguer vers le chat client
        Navigator.of(context).popUntil((route) => route.isFirst);
        // Ouvre le chat en changeant l'index
        break;
      case 'reservation':
      case 'checkin':
      case 'checkout':
      default:
        _showNotifDetail(context, _getTypeIcon(type), _getTypeColor(type));
    }
  }

  void _showNotifDetail(BuildContext context, IconData icon, Color color) {
    final title = data['title'] ?? data['titre'] ?? 'Notification';
    final message = data['message'] ?? '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
        ]),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? data['titre'] ?? 'Notification';
    final message = data['message'] ?? '';
    final type = data['type'] ?? 'general';
    final read = data['read'] as bool? ?? false;
    final createdAt = data['createdAt'] as Timestamp?;

    final timeStr = createdAt != null
        ? _formatTime(createdAt.toDate())
        : '';

    return InkWell(
      onTap: () => _handleTap(context),
      child: Container(
        color: read ? Colors.transparent : _primary.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône type
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getTypeColor(type).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTypeIcon(type),
                color: _getTypeColor(type),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                read ? FontWeight.w500 : FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (!read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      // ✅ Hint "Voir détails →"
                      Text(
                        _actionHint(type),
                        style: TextStyle(fontSize: 10, color: _getTypeColor(type), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _actionHint(String type) {
    switch (type) {
      case 'commande': return 'Voir la commande →';
      case 'reservation': return 'Voir les détails →';
      case 'checkin': return 'Voir les détails →';
      case 'checkout': return 'Voir les détails →';
      case 'message':
      case 'nouveau_message': return 'Ouvrir le chat →';
      default: return '';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'reservation':
        return const Color(0xFF9B4610);
      case 'commande':
        return Colors.orange;
      case 'checkin':
        return Colors.green;
      case 'checkout':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'reservation':
        return Icons.hotel_rounded;
      case 'commande':
        return Icons.room_service_rounded;
      case 'checkin':
        return Icons.login_rounded;
      case 'checkout':
        return Icons.logout_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return DateFormat('dd/MM/yyyy').format(dt);
  }
}