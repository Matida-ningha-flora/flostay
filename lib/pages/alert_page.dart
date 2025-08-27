import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  String _selectedAlertType = 'urgence';
  bool _isSubmitting = false;

  final Map<String, String> _alertTypes = {
    'urgence': 'Urgence',
    'proprete': 'Problème de propreté',
    'technique': 'Problème technique',
    'securite': 'Problème de sécurité',
    'autre': 'Autre',
  };

  Future<void> _submitAlert() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez décrire votre alerte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('alerts').add({
        'userId': user.uid,
        'userEmail': user.email,
        'alertType': _selectedAlertType,
        'message': _messageController.text,
        'status': 'new',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Envoyer une notification à la réception
      await _firestore.collection('notifications').add({
        'type': 'alert',
        'title': 'Nouvelle alerte: ${_alertTypes[_selectedAlertType]}',
        'message': '${user.email}: ${_messageController.text}',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alerte envoyée avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi de l\'alerte: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signaler une Alerte'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        leading: isWeb
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
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
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 40.0 : 16.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Signaler une alerte',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A2A10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Notre équipe interviendra au plus vite',
                        style: TextStyle(
                          color: Color(0xFF6D5D4F),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Type d\'alerte',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A2A10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedAlertType,
                        items: _alertTypes.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAlertType = value!;
                          });
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Description de l\'alerte',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A2A10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Décrivez en détail le problème...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitAlert,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B4610),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Envoyer l\'alerte',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}