import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DetailsCommandePage extends StatefulWidget {
  final String commandeId;
  
  const DetailsCommandePage({
    super.key,
    required this.commandeId,
  });

  @override
  State<DetailsCommandePage> createState() => _DetailsCommandePageState();
}

class _DetailsCommandePageState extends State<DetailsCommandePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _commandeData;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCommandeDetails();
  }

  Future<void> _loadCommandeDetails() async {
    try {
      final doc = await _firestore.collection('commandes').doc(widget.commandeId).get();
      
      if (doc.exists) {
        setState(() {
          _commandeData = doc.data()!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Commande non trouvée';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur de chargement: $e';
      });
    }
  }

  Future<void> _annulerCommande() async {
    try {
      await _firestore.collection('commandes').doc(widget.commandeId).update({
        'statut': 'annulee',
        'dateAnnulation': FieldValue.serverTimestamp(),
      });

      // Mettre à jour les données locales
      setState(() {
        _commandeData?['statut'] = 'annulee';
        _commandeData?['dateAnnulation'] = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande annulée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'annulation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAnnulationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Annuler la commande'),
          content: const Text('Êtes-vous sûr de vouloir annuler cette commande ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _annulerCommande();
              },
              child: const Text('Oui', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'en_attente':
        return 'En attente';
      case 'en_cours':
        return 'En cours de préparation';
      case 'terminee':
        return 'Terminée';
      case 'annulee':
        return 'Annulée';
      case 'livree':
        return 'Livrée';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'en_attente':
        return Colors.orange;
      case 'en_cours':
        return Colors.blue;
      case 'terminee':
        return Colors.green;
      case 'annulee':
        return Colors.red;
      case 'livree':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails de la commande')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails de la commande')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadCommandeDetails,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final commande = _commandeData!;
    final date = (commande['date'] as Timestamp).toDate();
    final formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(date);
    final status = commande['statut'] ?? 'inconnu';
    final total = commande['total'] ?? 0;
    final quantite = commande['quantite'] ?? 1;
    final prixUnitaire = commande['prixUnitaire'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la commande'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        actions: [
          if (status != 'annulee' && status != 'terminee' && status != 'livree')
            IconButton(
              onPressed: _showAnnulationDialog,
              icon: const Icon(Icons.cancel),
              tooltip: 'Annuler la commande',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec statut
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(status),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _getStatusColor(status),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statut: ${_getStatusText(status)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: $formattedDate',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Détails de la commande
            const Text(
              'Détails de la commande',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow('Produit', commande['item'] ?? 'Non spécifié'),
                    const Divider(),
                    _buildDetailRow('Description', commande['description'] ?? 'Aucune description'),
                    const Divider(),
                    _buildDetailRow('Prix unitaire', '$prixUnitaire FCFA'),
                    const Divider(),
                    _buildDetailRow('Quantité', quantite.toString()),
                    const Divider(),
                    _buildDetailRow(
                      'Total',
                      '$total FCFA',
                      isBold: true,
                      valueColor: const Color(0xFF9B4610),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instructions spéciales
            if (commande['instructions'] != null && commande['instructions'].toString().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instructions spéciales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(commande['instructions']),
                  ),
                ],
              ),
            const SizedBox(height: 24),


          
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}