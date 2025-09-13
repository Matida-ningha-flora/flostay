import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class OrdersAdminList extends StatefulWidget {
  const OrdersAdminList({Key? key}) : super(key: key);

  @override
  State<OrdersAdminList> createState() => _OrdersAdminListState();
}

class _OrdersAdminListState extends State<OrdersAdminList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterStatus = 'all';
  final List<String> _statusOptions = [
    'all',
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'delivered',
    'cancelled'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Commandes'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        actions: [
          // Filtre des commandes par statut
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _filterStatus,
              dropdownColor: const Color(0xFF9B4610),
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(
                    'Toutes',
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'pending',
                  child: Text(
                    'En attente',
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'confirmed',
                  child: Text(
                    'Confirmées',
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'preparing',
                  child: Text(
                    'En préparation',
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'ready',
                  child: Text(
                    'Prêtes',
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'delivered',
                  child: Text(
                    'Livrées',
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'cancelled',
                  child: Text(
                    'Annulées',
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                ),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: _filterStatus == 'all'
              ? _firestore
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .snapshots()
              : _firestore
                  .collection('orders')
                  .where('status', isEqualTo: _filterStatus)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
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
                      'Erreur de chargement des commandes',
                      style: GoogleFonts.roboto(
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
                      Icons.shopping_cart,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filterStatus == 'all'
                          ? 'Aucune commande'
                          : 'Aucune commande ${_getStatusText(_filterStatus).toLowerCase()}',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            final orders = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index].data() as Map<String, dynamic>;
                final orderId = orders[index].id;
                
                return _buildOrderCard(context, order, orderId);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order, String orderId) {
    final createdAt = order['createdAt'] != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(
            (order['createdAt'] as Timestamp).toDate())
        : 'Date inconnue';
    
    final status = order['status'] ?? 'pending';
    final roomNumber = order['roomNumber'] ?? 'Non spécifié';
    final userName = order['userName'] ?? 'Client inconnu';
    final userEmail = order['userEmail'] ?? 'Email inconnu';
    final items = order['items'] ?? [];
    final totalAmount = order['totalAmount']?.toString() ?? '0';
    final specialInstructions = order['specialInstructions'] ?? '';

    Color statusColor;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        break;
      case 'preparing':
        statusColor = Colors.deepPurple;
        break;
      case 'ready':
        statusColor = Colors.green;
        break;
      case 'delivered':
        statusColor = Colors.teal;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        leading: Icon(
          Icons.shopping_cart,
          color: statusColor,
        ),
        title: Text(
          'Commande #${orderId.substring(0, 8)}',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4A2A10),
          ),
        ),
        subtitle: Text('$userName • Chambre $roomNumber'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            _getStatusText(status),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderInfo('Client:', '$userName ($userEmail)'),
                _buildOrderInfo('Chambre:', roomNumber),
                _buildOrderInfo('Date:', createdAt),
                _buildOrderInfo('Statut:', _getStatusText(status)),
                
                const SizedBox(height: 12),
                const Text(
                  'Articles commandés:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF4A2A10),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Liste des articles
                ...items.map<Widget>((item) {
                  final itemName = item['name'] ?? 'Article inconnu';
                  final itemQuantity = item['quantity']?.toString() ?? '1';
                  final itemPrice = item['price']?.toString() ?? '0';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text('• $itemName'),
                        const Spacer(),
                        Text('x$itemQuantity'),
                        const SizedBox(width: 16),
                        Text('${itemPrice}FCFA'),
                      ],
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${totalAmount}FCFA',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF9B4610),
                      ),
                    ),
                  ],
                ),
                
                if (specialInstructions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Instructions spéciales:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF4A2A10),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(specialInstructions),
                ],
                
                const SizedBox(height: 16),
                
                // Actions selon le statut
                if (status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'confirmed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirmer'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'cancelled'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                    ],
                  ),
                
                if (status == 'confirmed')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'preparing'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('En préparation'),
                        ),
                      ),
                    ],
                  ),
                
                if (status == 'preparing')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'ready'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Prête à servir'),
                        ),
                      ),
                    ],
                  ),
                
                if (status == 'ready')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'delivered'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Marquer comme livrée'),
                        ),
                      ),
                    ],
                  ),
                
                if (status == 'delivered')
                  const Text(
                    'Commande livrée avec succès',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                
                if (status == 'cancelled')
                  const Text(
                    'Commande annulée',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prête';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut de la commande mis à jour: ${_getStatusText(newStatus)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}