import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Pour Clipboard

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _responseController = TextEditingController();
  String _selectedAlertType = 'proprete';
  bool _isSubmitting = false;
  String? _selectedAlertId;
  bool _isAdmin = false;
  bool _isReceptionist = false;
  bool _isLoading = true;
  String _errorMessage = '';

  final Map<String, String> _alertTypes = {
    'urgence': 'Urgence',
    'proprete': 'Problème de propreté',
    'technique': 'Problème technique',
    'securite': 'Problème de sécurité',
    'autre': 'Autre',
  };

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final role = userDoc.data()?['role'] ?? 'client';
          setState(() {
            _isAdmin = role == 'admin';
            _isReceptionist = role == 'receptionniste';
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur lors de la vérification du rôle: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur de chargement des informations utilisateur';
      });
    }
  }

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
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous devez être connecté pour envoyer une alerte'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Récupérer les informations utilisateur
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? user.email?.split('@')[0] ?? 'Utilisateur';
      final userRoom = userDoc.data()?['currentRoom'] ?? 'Non spécifié';

      await _firestore.collection('alerts').add({
        'userId': user.uid,
        'userEmail': user.email,
        'userName': userName,
        'userRoom': userRoom,
        'alertType': _selectedAlertType,
        'message': _messageController.text,
        'status': 'new',
        'timestamp': FieldValue.serverTimestamp(),
        'responses': [],
        'assignedTo': null,
        'priority': _selectedAlertType == 'urgence' ? 'high' : 'medium',
      });

      // Notification pour l'administration
      await _firestore.collection('notifications').add({
        'type': 'alert',
        'title': 'Nouvelle alerte: ${_alertTypes[_selectedAlertType]}',
        'message': '$userName (Chambre $userRoom): ${_messageController.text}',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'alertType': _selectedAlertType,
        'priority': _selectedAlertType == 'urgence' ? 'high' : 'medium',
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

  Future<void> _addResponse(String alertId) async {
    if (_responseController.text.isEmpty) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? user.email?.split('@')[0] ?? 'Staff';
      final userRole = userDoc.data()?['role'] ?? 'staff';

      await _firestore.collection('alerts').doc(alertId).update({
        'responses': FieldValue.arrayUnion([
          {
            'userId': user.uid,
            'userName': userName,
            'message': _responseController.text,
            'timestamp': FieldValue.serverTimestamp(),
            'role': userRole,
          }
        ]),
        'status': 'in_progress',
        'assignedTo': user.uid,
        'assignedToName': userName,
      });

      // Notification pour l'utilisateur
      final alertDoc = await _firestore.collection('alerts').doc(alertId).get();
      final alertData = alertDoc.data();
      
      if (alertData != null && alertData['userId'] != null) {
        await _firestore.collection('notifications').add({
          'type': 'alert_response',
          'userId': alertData['userId'],
          'title': 'Réponse à votre alerte',
          'message': '$userName a répondu à votre alerte: ${_responseController.text}',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'alertId': alertId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réponse envoyée'),
          backgroundColor: Colors.green,
        ),
      );

      _responseController.clear();
      setState(() {
        _selectedAlertId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi de la réponse: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateAlertStatus(String alertId, String status) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update({
        'status': status,
        'resolvedAt': status == 'resolved' ? FieldValue.serverTimestamp() : null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alerte marquée comme ${status == 'resolved' ? 'résolue' : 'en cours'}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showIndexCreationDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Création d'index requis"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pour afficher les alertes, vous devez créer un index Firestore."),
            const SizedBox(height: 16),
            const Text("Cliquez sur le lien ci-dessous pour créer l'index :"),
            const SizedBox(height: 8),
            SelectableText(
              url,
              style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
          TextButton(
            onPressed: () {
              // Copier le lien dans le presse-papier
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Lien copié dans le presse-papier"),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text("Copier le lien"),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertForm() {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
        child: Column(
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
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B4610),
                  foregroundColor: Colors.white,
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
    );
  }

  Widget _buildAlertItem(DocumentSnapshot doc, bool isStaff) {
    final data = doc.data() as Map<String, dynamic>;
    final alertType = _alertTypes[data['alertType']] ?? 'Autre';
    final message = data['message'] ?? '';
    final status = data['status'] ?? 'new';
    final timestamp = data['timestamp'] != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format((data['timestamp'] as Timestamp).toDate())
        : 'Date inconnue';
    final userName = data['userName'] ?? data['userEmail'] ?? 'Utilisateur inconnu';
    final userRoom = data['userRoom'] ?? 'Chambre inconnue';
    final responses = List<Map<String, dynamic>>.from(data['responses'] ?? []);
    final assignedToName = data['assignedToName'] ?? 'Non assigné';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'new':
        statusColor = Colors.red;
        statusText = 'Nouveau';
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusText = 'En cours';
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusText = 'Résolu';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Inconnu';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(
          Icons.warning,
          color: statusColor,
        ),
        title: Text('$alertType - $userName (Chambre $userRoom)'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$timestamp - $statusText'),
            if (isStaff && assignedToName != null)
              Text('Assigné à: $assignedToName', style: const TextStyle(fontSize: 12)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Réponses:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (responses.isEmpty)
                  const Text('Aucune réponse pour le moment'),
                ...responses.map((response) {
                  return ListTile(
                    leading: const Icon(Icons.message, size: 20),
                    title: Text(response['message'] ?? ''),
                    subtitle: Text(
                      '${response['userName'] ?? 'Staff'} (${response['role'] ?? 'staff'}) - ${DateFormat('dd/MM/yyyy HH:mm').format((response['timestamp'] as Timestamp).toDate())}',
                    ),
                  );
                }).toList(),
                if (isStaff && status != 'resolved')
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      TextField(
                        controller: _responseController,
                        decoration: InputDecoration(
                          labelText: 'Votre réponse',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () => _addResponse(doc.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => _updateAlertStatus(doc.id, 'in_progress'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text('En cours'),
                          ),
                          ElevatedButton(
                            onPressed: () => _updateAlertStatus(doc.id, 'resolved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Résolu'),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertList(bool isStaff) {
    Query query = _firestore.collection('alerts').orderBy('timestamp', descending: true);
    
    if (!isStaff) {
      final user = _auth.currentUser;
      if (user != null) {
        query = query.where('userId', isEqualTo: user.uid);
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF9B4610)));
        }

        if (snapshot.hasError) {
          String error = snapshot.error.toString();
          if (error.contains('index')) {
            // C'est une erreur d'index, affichons un message avec un bouton pour créer l'index
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 50, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Index requis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cette requête nécessite un index Firestore.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Extraire l'URL de l'erreur
                      final regex = RegExp(r'https://console\.firebase\.google\.com[^\s]+');
                      final match = regex.firstMatch(error);
                      if (match != null) {
                        final url = match.group(0);
                        _showIndexCreationDialog(url!);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B4610),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Créer l\'index'),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 50, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Erreur de chargement des alertes',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
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
        }

        final alerts = snapshot.data!.docs;

        if (alerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning, size: 50, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  isStaff ? 'Aucune alerte pour le moment' : 'Vous n\'avez aucune alerte',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            return _buildAlertItem(alerts[index], isStaff);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;
    final isStaff = _isAdmin || _isReceptionist;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des Alertes'),
          backgroundColor: const Color(0xFF9B4610),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF9B4610)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Alertes'),
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
          padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isStaff) _buildAlertForm(),
              const SizedBox(height: 24),
              Text(
                isStaff ? 'Toutes les alertes' : 'Mes alertes',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A2A10),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildAlertList(isStaff),
              ),
            ],
          ),
        ),
      ),
    );
  }
}