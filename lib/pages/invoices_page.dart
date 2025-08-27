import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .get();

      setState(() {
        _invoices = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur de chargement des factures: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Factures'),
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
            : _invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune facture',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Vos factures apparaîtront ici',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
                    child: ListView.builder(
                      itemCount: _invoices.length,
                      itemBuilder: (context, index) {
                        return _buildInvoiceCard(_invoices[index], isWeb);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice, bool isWeb) {
    final date = invoice['date'] is Timestamp
        ? (invoice['date'] as Timestamp).toDate()
        : DateTime.now();

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
                  'Facture #${invoice['invoiceNumber'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A2A10),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(invoice['status'] ?? 'paid'),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(invoice['status'] ?? 'paid'),
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
            Text(
              'Date: ${DateFormat('dd/MM/yyyy').format(date)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Chambre: ${invoice['roomType'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Durée: ${invoice['nights'] ?? '0'} nuit(s)',
              style: TextStyle(color: Colors.grey.shade600),
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
                  '${invoice['totalAmount'] ?? '0'} FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9B4610),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implémenter le téléchargement/visualisation de la facture
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B4610),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Voir la facture'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'Payée';
      case 'pending':
        return 'En attente';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }
}