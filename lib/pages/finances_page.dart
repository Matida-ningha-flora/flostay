import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FinancesPage extends StatelessWidget {
  const FinancesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finances'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final transactions = snapshot.data!.docs;

          double totalRevenue = 0;
          for (var transaction in transactions) {
            final data = transaction.data() as Map<String, dynamic>;
            if (data['type'] == 'revenue') {
              totalRevenue += (data['amount'] ?? 0).toDouble();
            }
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Revenu Total',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          '${totalRevenue.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9B4610),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Dernières transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final data =
                          transactions[index].data() as Map<String, dynamic>;
                      final amount = data['amount'] ?? 0;
                      final description = data['description'] ?? '';
                      final date = data['date'] != null
                          ? DateFormat('dd/MM/yyyy').format(
                              (data['date'] as Timestamp).toDate())
                          : 'Date inconnue';
                      final type = data['type'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(description),
                          subtitle: Text(date),
                          trailing: Text(
                            '${amount.toString()} FCFA',
                            style: TextStyle(
                              color: type == 'revenue'
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      )
    );
  }
}