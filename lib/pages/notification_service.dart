// ============================================================
// notification_service.dart
//
// Service centralisé de notifications pour FLOSTAY.
// - Crée des notifications Firestore pour le client
// - Utilisé par la réception quand elle valide réservations/commandes
// - Le client voit ses notifications en temps réel
//
// Collection Firestore : notifications
// Champs : userId, title, message, type, status, createdAt, read
// Types : reservation, commande, checkin, checkout, general
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;

  // ── Créer une notification pour un client ─────────────────────────────────

  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // 'reservation', 'commande', 'checkin', 'checkout', 'general'
    String? reservationId,
    String? commandeId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        if (reservationId != null) 'reservationId': reservationId,
        if (commandeId != null) 'commandeId': commandeId,
      });
    } catch (e) {
      print('Erreur création notification: $e');
    }
  }

  // ── Notifications réservation ─────────────────────────────────────────────

  static Future<void> notifyReservationConfirmed({
    required String userId,
    required String reservationId,
    required String roomType,
  }) async {
    await createNotification(
      userId: userId,
      title: '✅ Réservation confirmée',
      message: 'Votre réservation pour une $roomType a été confirmée par la réception.',
      type: 'reservation',
      reservationId: reservationId,
    );
  }

  static Future<void> notifyReservationCancelled({
    required String userId,
    required String reservationId,
  }) async {
    await createNotification(
      userId: userId,
      title: '❌ Réservation annulée',
      message: 'Votre réservation a été annulée. Contactez la réception pour plus d\'informations.',
      type: 'reservation',
      reservationId: reservationId,
    );
  }

  static Future<void> notifyCheckInApproved({
    required String userId,
    required String reservationId,
    required String roomNumber,
  }) async {
    await createNotification(
      userId: userId,
      title: '🏨 Check-in confirmé',
      message: 'Bienvenue ! Votre check-in est confirmé. Chambre n°$roomNumber.',
      type: 'checkin',
      reservationId: reservationId,
    );
  }

  static Future<void> notifyCheckOutApproved({
    required String userId,
    required String reservationId,
  }) async {
    await createNotification(
      userId: userId,
      title: '👋 Check-out confirmé',
      message: 'Votre check-out a été effectué. Merci pour votre séjour chez FLOSTAY !',
      type: 'checkout',
      reservationId: reservationId,
    );
  }

  // ── Notifications commande ────────────────────────────────────────────────

  static Future<void> notifyCommandeEnCours({
    required String userId,
    required String commandeId,
    required String itemName,
  }) async {
    await createNotification(
      userId: userId,
      title: '👨‍🍳 Commande en préparation',
      message: 'Votre commande "$itemName" est en cours de préparation.',
      type: 'commande',
      commandeId: commandeId,
    );
  }

  static Future<void> notifyCommandeTerminee({
    required String userId,
    required String commandeId,
    required String itemName,
  }) async {
    await createNotification(
      userId: userId,
      title: '✅ Commande livrée',
      message: 'Votre commande "$itemName" a été livrée. Bon appétit !',
      type: 'commande',
      commandeId: commandeId,
    );
  }

  static Future<void> notifyCommandeAnnulee({
    required String userId,
    required String commandeId,
    required String itemName,
  }) async {
    await createNotification(
      userId: userId,
      title: '❌ Commande annulée',
      message: 'Votre commande "$itemName" a été annulée.',
      type: 'commande',
      commandeId: commandeId,
    );
  }

  // ── Marquer une notification comme lue ───────────────────────────────────

  static Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  static Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final unread = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── Stream notifications non lues ────────────────────────────────────────

  static Stream<int> unreadCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  // ── Stream toutes notifications ───────────────────────────────────────────

  static Stream<QuerySnapshot> notificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }
}