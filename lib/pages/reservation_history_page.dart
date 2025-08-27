import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ReservationHistoryPage extends StatefulWidget {
  const ReservationHistoryPage({super.key});

  @override
  State<ReservationHistoryPage> createState() => _ReservationHistoryPageState();
}

class _ReservationHistoryPageState extends State<ReservationHistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _reservations = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _hasIndexError = false;
  String _indexUrl = '';

  @override
  void initState() {
    super.initState();
    _loadReservationHistory();
  }

  Future<void> _loadReservationHistory() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Utilisateur non connecté';
      });
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _reservations = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        _isLoading = false;
        _hasIndexError = false;
      });
    } catch (e) {
      print("Erreur de chargement de l'historique: $e");
      
      // Vérifier si c'est une erreur d'index
      if (e.toString().contains('index') && e.toString().contains('create_composite')) {
        // Extraire l'URL de création d'index depuis le message d'erreur
        final regex = RegExp(r'https://console\.firebase\.google\.com[^\s]+');
        final match = regex.firstMatch(e.toString());
        
        setState(() {
          _isLoading = false;
          _hasIndexError = true;
          _errorMessage = 'Configuration requise pour afficher l\'historique';
          if (match != null) {
            _indexUrl = match.group(0)!;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de chargement: $e';
          _hasIndexError = false;
        });
      }
    }
  }

  Future<void> _cancelReservation(String reservationId) async {
    try {
      await _firestore.collection('reservations').doc(reservationId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Créer une notification d'annulation
      final user = _auth.currentUser;
      if (user != null) {
        final reservation = _reservations.firstWhere((r) => r['id'] == reservationId);
        
        await _firestore.collection('notifications').add({
          'type': 'cancellation',
          'title': 'Réservation annulée',
          'message': '${reservation['userName']} a annulé sa réservation de ${reservation['roomType']}',
          'reservationId': reservationId,
          'userId': user.uid,
          'userEmail': user.email,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // Recharger l'historique
      _loadReservationHistory();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Réservation annulée avec succès"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'annulation: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
    } else if (timestamp is DateTime) {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    }
    return 'Date inconnue';
  }

  String _formatPrice(dynamic price) {
    if (price is int || price is double) {
      return '$price FCFA';
    } else if (price is String) {
      return '$price FCFA';
    }
    return '0 FCFA';
  }

  Future<void> _launchIndexUrl() async {
    if (_indexUrl.isNotEmpty) {
      final Uri url = Uri.parse(_indexUrl);
      if (!await launchUrl(url)) {
        throw Exception('Impossible d\'ouvrir l\'URL: $url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Réservations'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F0E5),
              Color(0xFFFDF8F3),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasIndexError
                ? _buildIndexErrorWidget()
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 60, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _loadReservationHistory,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _reservations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 60, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucune réservation',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Vos réservations apparaîtront ici',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
                            child: ListView.builder(
                              itemCount: _reservations.length,
                              itemBuilder: (context, index) {
                                return _buildReservationCard(_reservations[index], isWeb);
                              },
                            ),
                          ),
      ),
    );
  }

  Widget _buildIndexErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build, size: 60, color: Colors.orange),
          const SizedBox(height: 20),
          const Text(
            'Configuration requise',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pour afficher votre historique de réservations, une configuration technique est nécessaire.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Votre réservation a bien été enregistrée',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Même si l\'historique ne s\'affiche pas actuellement, soyez assuré que votre réservation a été enregistrée avec succès.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_indexUrl.isNotEmpty)
                    Column(
                      children: [
                        const Text(
                          'Un administrateur doit configurer la base de données:',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _launchIndexUrl,
                          child: const Text('Configurer la base de données'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadReservationHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B4610),
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reservation, bool isWeb) {
    final checkInDate = reservation['checkInDate'];
    final checkOutDate = reservation['checkOutDate'];
    final status = reservation['status'] ?? 'pending';
    final roomNumber = reservation['roomNumber'] ?? 'Non attribué';
    final totalAmount = reservation['totalAmount'] ?? reservation['price'] ?? 0;

    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: isWeb ? 20.0 : 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reservation['roomType'] ?? 'Chambre',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A2A10),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.meeting_room, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Chambre: $roomNumber',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Arrivée: ${_formatTimestamp(checkInDate)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Départ: ${_formatTimestamp(checkOutDate)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Personnes: ${reservation['guests'] ?? '1'}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatPrice(totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9B4610),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (status == 'pending' || status == 'confirmed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _showCancelConfirmationDialog(reservation['id']);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Annuler la réservation'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmationDialog(String reservationId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer l'annulation"),
          content: const Text("Êtes-vous sûr de vouloir annuler cette réservation ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Non"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelReservation(reservationId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text("Oui, annuler"),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'checked-in':
        return Colors.blue;
      case 'checked-out':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmée';
      case 'checked-in':
        return 'En cours';
      case 'checked-out':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      case 'pending':
      default:
        return 'En attente';
    }
  }
}