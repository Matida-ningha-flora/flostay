import 'package:flutter/material.dart';

class AnalysesIAPage extends StatelessWidget {
  const AnalysesIAPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyses IA'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyses et Recommandations',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            _buildIACard(
              'Tendances de réservation',
              'Augmentation de 15% des réservations de chambres prestige ce mois-ci',
              Icons.trending_up,
            ),
            _buildIACard(
              'Recommandation de prix',
              'Augmenter le prix des chambres standard de 5% pendant la haute saison',
              Icons.attach_money,
            ),
            _buildIACard(
              'Préférences clients',
              'Les clients préfèrent les chambres avec vue sur la piscine',
              Icons.people,
            ),
            _buildIACard(
              'Optimisation des services',
              'Ajouter plus d\'options de petit-déjeuner pour attirer une clientèle internationale',
              Icons.restaurant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIACard(String title, String content, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF9B4610)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(content),
      ),
    );
  }
}