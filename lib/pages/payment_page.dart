import 'package:flutter/material.dart';
import 'package:flostay/pages/reservations_page.dart';

class PaymentPage extends StatelessWidget {
  final String roomTitle;
  final int roomPrice;

  const PaymentPage({
    super.key,
    required this.roomTitle,
    required this.roomPrice, required String phoneNumber, required String checkInDate, required String checkOutDate, required String fullName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: const Color.fromARGB(255, 37, 55, 138),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Chambre : $roomTitle",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Montant total : $roomPrice FCFA",
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            const Text("Choisissez votre mode de paiement :",
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            PaymentOption(
              label: "MTN Mobile Money",
              icon: Icons.phone_android,
              onTap: () {
                _showSuccessDialog(context, "MTN Mobile Money");
              },
            ),
            const SizedBox(height: 15),
            PaymentOption(
              label: "Orange Money",
              icon: Icons.phone_iphone,
              onTap: () {
                _showSuccessDialog(context, "Orange Money");
              },
            ),
            const SizedBox(height: 15),
            PaymentOption(
              label: "Carte bancaire",
              icon: Icons.credit_card,
              onTap: () {
                _showSuccessDialog(context, "Carte bancaire");
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String method) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Paiement réussi"),
        content: Text("Votre paiement via $method a été effectué avec succès."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }
}

class PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const PaymentOption({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color.fromARGB(255, 42, 56, 145)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color.fromARGB(255, 42, 56, 145)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 16),
            )
          ],
        ),
      ),
    );
  }
}
