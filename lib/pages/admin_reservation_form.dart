import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminReservationsPage extends StatefulWidget {
  const AdminReservationsPage({Key? key}) : super(key: key);

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterStatus = 'tous';
  final Map<String, int> _stats = {
    'todayCheckins': 0,
    'todayCheckouts': 0,
    'activeReservations': 0,
    'weeklyRevenue': 0,
    'totalClients': 0,
    'totalReceptionists': 0,
    'totalReservations': 0,
    'totalOrders': 0,
    'totalReviews': 0,
    'unreadAlerts': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    await Future.wait([
      _loadReservationStats(),
      _loadUserStats(),
      _loadOrderStats(),
      _loadReviewStats(),
      _loadAlertStats(),
    ]);
  }

  Future<void> _loadReservationStats() async {
    final today = DateTime.now();
    final todayFormatted = _formatDate(today);
    
    // Check-ins d'aujourd'hui
    final checkinsSnapshot = await _firestore
        .collection('reservations')
        .where('checkInDate', isEqualTo: todayFormatted)
        .where('statut', whereIn: ['confirmée', 'checkin', 'checkout'])
        .get();
    
    // Check-outs d'aujourd'hui
    final checkoutsSnapshot = await _firestore
        .collection('reservations')
        .where('checkOutDate', isEqualTo: todayFormatted)
        .where('statut', whereIn: ['confirmée', 'checkin', 'checkout'])
        .get();
    
    // Réservations actives
    final activeReservationsSnapshot = await _firestore
        .collection('reservations')
        .where('statut', whereIn: ['confirmée', 'checkin'])
        .get();
    
    // Revenu de la semaine
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    final revenueSnapshot = await _firestore
        .collection('reservations')
        .where('dateCreation', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('dateCreation', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
        .where('statut', whereIn: ['confirmée', 'checkin', 'checkout'])
        .get();
    
    int weeklyRevenue = 0;
    for (var doc in revenueSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      weeklyRevenue += ((data['prixTotal'] ?? 0) as num).toInt();
    }

    // Total des réservations
    final allReservationsSnapshot = await _firestore
        .collection('reservations')
        .get();

    setState(() {
      _stats['todayCheckins'] = checkinsSnapshot.docs.length;
      _stats['todayCheckouts'] = checkoutsSnapshot.docs.length;
      _stats['activeReservations'] = activeReservationsSnapshot.docs.length;
      _stats['weeklyRevenue'] = weeklyRevenue;
      _stats['totalReservations'] = allReservationsSnapshot.docs.length;
    });
  }

  Future<void> _loadUserStats() async {
    // Total clients
    final clientsSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'client')
        .get();
    
    // Total réceptionnistes
    final receptionistsSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'receptionniste')
        .get();

    setState(() {
      _stats['totalClients'] = clientsSnapshot.docs.length;
      _stats['totalReceptionists'] = receptionistsSnapshot.docs.length;
    });
  }

  Future<void> _loadOrderStats() async {
    // Total des commandes
    final ordersSnapshot = await _firestore
        .collection('orders')
        .get();

    setState(() {
      _stats['totalOrders'] = ordersSnapshot.docs.length;
    });
  }

  Future<void> _loadReviewStats() async {
    // Total des avis
    final reviewsSnapshot = await _firestore
        .collection('reviews')
        .get();

    setState(() {
      _stats['totalReviews'] = reviewsSnapshot.docs.length;
    });
  }

  Future<void> _loadAlertStats() async {
    // Alertes non lues
    final alertsSnapshot = await _firestore
        .collection('alerts')
        .where('status', isEqualTo: 'new')
        .get();

    setState(() {
      _stats['unreadAlerts'] = alertsSnapshot.docs.length;
    });
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Widget _buildStatsCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tableau de Bord Administrateur',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllStats,
            tooltip: 'Actualiser les statistiques',
          ),
        ],
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Section Statistiques Générales
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistiques Générales',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4A2A10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildStatsCard('Clients', _stats['totalClients']!, Icons.people, Colors.blue),
                        _buildStatsCard('Réceptionnistes', _stats['totalReceptionists']!, Icons.badge, Colors.purple),
                        _buildStatsCard('Réservations', _stats['totalReservations']!, Icons.hotel, Colors.orange),
                        _buildStatsCard('Commandes', _stats['totalOrders']!, Icons.restaurant, Colors.green),
                        _buildStatsCard('Check-In Aujourd\'hui', _stats['todayCheckins']!, Icons.login, Colors.teal),
                        _buildStatsCard('Check-out Aujourd\'hui', _stats['todayCheckouts']!, Icons.logout, Colors.indigo),
                        _buildStatsCard('Avis Clients', _stats['totalReviews']!, Icons.star, Colors.amber),
                        _buildStatsCard('Alertes Non Lus', _stats['unreadAlerts']!, Icons.notifications, Colors.red),
                        _buildStatsCard('Réservations Actives', _stats['activeReservations']!, Icons.event_available, Colors.green),
                        _buildStatsCard('Revenu Hebdo (FCFA)', _stats['weeklyRevenue']!, Icons.attach_money, Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),

              // Section Réservations
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion des Réservations',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4A2A10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Filtre de statut
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_list, size: 20, color: Color(0xFF9B4610)),
                            const SizedBox(width: 8),
                            Text(
                              'Filtrer:',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4A2A10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _filterStatus,
                                isExpanded: true,
                                underline: const SizedBox(),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF4A2A10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'tous', child: Text('Toutes les réservations')),
                                  DropdownMenuItem(value: 'confirmée', child: Text('Confirmées')),
                                  DropdownMenuItem(value: 'en_attente', child: Text('En attente')),
                                  DropdownMenuItem(value: 'annulée', child: Text('Annulées')),
                                  DropdownMenuItem(value: 'checkin', child: Text('Check-in')),
                                  DropdownMenuItem(value: 'checkout', child: Text('Check-out')),
                                ],
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _filterStatus = newValue!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Liste des réservations
                    SizedBox(
                      height: 400,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _getReservationsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B4610)),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Erreur de chargement',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucune réservation',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final reservations = snapshot.data!.docs;

                          return ListView.builder(
                            itemCount: reservations.length,
                            itemBuilder: (context, index) {
                              final reservation = reservations[index].data() as Map<String, dynamic>;
                              final reservationId = reservations[index].id;
                              final arrivalDate = (reservation['dateArrivee'] as Timestamp).toDate();
                              final departureDate = (reservation['dateDepart'] as Timestamp).toDate();
                              final status = reservation['statut'] ?? 'en_attente';
                              final userName = reservation['userName'] ?? 'Client inconnu';
                              final userEmail = reservation['userEmail'] ?? 'Email inconnu';

                              return _buildReservationCard(
                                context,
                                reservation,
                                reservationId,
                                arrivalDate,
                                departureDate,
                                status,
                                userName,
                                userEmail,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getReservationsStream() {
    Query query = _firestore
        .collection('reservations')
        .orderBy('dateCreation', descending: true);

    if (_filterStatus != 'tous') {
      query = query.where('statut', isEqualTo: _filterStatus);
    }

    return query.snapshots();
  }

  Future<void> _updateReservationStatus(String reservationId, String status) async {
    try {
      final updateData = {
        'statut': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser!.uid,
      };

      if (status == 'checkin') {
        updateData['checkInDate'] = _formatDate(DateTime.now());
        updateData['checkInBy'] = _auth.currentUser!.uid;
      } else if (status == 'checkout') {
        updateData['checkOutDate'] = _formatDate(DateTime.now());
        updateData['checkOutBy'] = _auth.currentUser!.uid;
      }

      await _firestore.collection('reservations').doc(reservationId).update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Réservation ${status == 'checkin' ? 'check-in' : 'check-out'} effectué'),
          backgroundColor: Colors.green,
        ),
      );

      _loadReservationStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildReservationCard(
    BuildContext context,
    Map<String, dynamic> reservation,
    String reservationId,
    DateTime arrivalDate,
    DateTime departureDate,
    String status,
    String userName,
    String userEmail,
  ) {
    final nights = reservation['nuits']?.toString() ?? '0';
    final guests = reservation['nombrePersonnes']?.toString() ?? '0';
    final totalPrice = reservation['prixTotal']?.toString() ?? '0';
    final roomName = reservation['chambre']?.toString() ?? 'Chambre inconnue';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'confirmée':
        statusColor = Colors.green;
        statusText = 'Confirmée';
        break;
      case 'annulée':
        statusColor = Colors.red;
        statusText = 'Annulée';
        break;
      case 'checkin':
        statusColor = Colors.blue;
        statusText = 'Check-in';
        break;
      case 'checkout':
        statusColor = Colors.purple;
        statusText = 'Check-out';
        break;
      case 'en_attente':
      default:
        statusColor = Colors.orange;
        statusText = 'En attente';
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  roomName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF4A2A10),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$userName ($userEmail)'),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(DateFormat('dd/MM/yyyy').format(arrivalDate)),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(DateFormat('dd/MM/yyyy').format(departureDate)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.hotel, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('$nights nuits'),
                const SizedBox(width: 16),
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('$guests personnes'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('$totalPrice FCFA'),
              ],
            ),
            const SizedBox(height: 12),
            
            // Actions selon le statut
            if (status == 'confirmée')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateReservationStatus(reservationId, 'checkin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Check-in'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateReservationStatus(reservationId, 'checkout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Check-out'),
                    ),
                  ),
                ],
              ),
            
            if (status == 'en_attente')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateReservationStatus(reservationId, 'confirmée'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirmer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateReservationStatus(reservationId, 'annulée'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}