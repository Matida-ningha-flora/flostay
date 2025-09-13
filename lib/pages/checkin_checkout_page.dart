import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CheckInOutPage extends StatefulWidget {
  const CheckInOutPage({super.key});

  @override
  State<CheckInOutPage> createState() => _CheckInOutPageState();
}

class _CheckInOutPageState extends State<CheckInOutPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _reservations = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _userRole = 'client';
  bool _showCheckInForm = false;
  bool _showCheckOutForm = false;
  bool _hasActiveReservation = false;
  bool _hasCheckedInReservation = false;
  bool _hasIndexError = false;
  String _indexUrl = '';
  bool _checkInWithoutReservation = false;

  // Contrôleurs pour le formulaire simplifié
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _specialRequestsController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  String _selectedIdType = 'Carte d\'identité';
  String _selectedPaymentMethod = 'Espèces';
  String _selectedRoomType = 'Premium';
  
  // Prix des chambres
  final Map<String, int> _roomPrices = {
    'Premium': 48580,
    'Prestige': 58580,
    'Deluxe': 78580,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _specialRequestsController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Utilisateur non connecté';
      });
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'] ?? 'client';
        });
      }
      await _loadReservations();
    } catch (e) {
      print("Erreur de chargement du rôle utilisateur: $e");
      await _loadReservations();
    }
  }

  Future<void> _loadReservations() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Utilisateur non connecté';
      });
      return;
    }

    try {
      QuerySnapshot snapshot;
      
      if (_userRole == 'admin' || _userRole == 'staff') {
        // Pour le staff, charger toutes les réservations
        snapshot = await _firestore
            .collection('reservations')
            .get();
      } else {
        // Pour les clients, charger seulement leurs réservations
        snapshot = await _firestore
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .get();
      }

      // Filtrer les réservations après les avoir récupérées
      final allReservations = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      // Filtrer pour n'avoir que les réservations actives
      setState(() {
        _reservations = allReservations.where((reservation) {
          final status = reservation['status'] ?? '';
          return status == 'confirmed' || status == 'checked-in';
        }).toList();

        _hasActiveReservation = _reservations.isNotEmpty;
        _hasCheckedInReservation = _reservations.any((reservation) => reservation['status'] == 'checked-in');
        _isLoading = false;
        _hasIndexError = false;
      });
    } catch (e) {
      print("Erreur de chargement des réservations: $e");
      
      // Vérifier si c'est une erreur d'index
      if (e.toString().contains('index') && e.toString().contains('create_composite')) {
        final regex = RegExp(r'https://console\.firebase\.google\.com[^\s]+');
        final match = regex.firstMatch(e.toString());

        setState(() {
          _isLoading = false;
          _hasIndexError = true;
          _errorMessage = 'Configuration requise pour afficher les réservations';
          if (match != null) {
            _indexUrl = match.group(0)!;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de chargement des réservations';
        });
      }
    }
  }

  Future<void> _launchIndexUrl() async {
    if (_indexUrl.isNotEmpty) {
      final Uri url = Uri.parse(_indexUrl);
      if (!await launchUrl(url)) {
        throw Exception('Impossible d\'ouvrir l\'URL: $url');
      }
    }
  }

  Future<void> _submitCheckInRequest(bool hasReservation, [Map<String, dynamic>? reservation]) async {
    if (_idNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir votre numéro de pièce d\'identité')),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Récupérer les informations utilisateur depuis Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final checkInData = {
        'clientName': userData['name'] ?? '',
        'clientEmail': user.email ?? '',
        'clientPhone': userData['phone'] ?? '',
        'idType': _selectedIdType,
        'idNumber': _idNumberController.text,
        'specialRequests': _specialRequestsController.text,
        'checkInDate': FieldValue.serverTimestamp(),
        'status': 'pending',
        'userId': user.uid,
        'userEmail': user.email,
        'hasReservation': hasReservation,
        'reservationId': reservation != null ? reservation['id'] : null,
        'roomType': hasReservation ? (reservation?['roomType'] ?? 'Premium') : _selectedRoomType,
        'price': hasReservation ? (reservation?['price'] ?? _roomPrices['Premium']) : _roomPrices[_selectedRoomType],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Enregistrer la demande de check-in
      await _firestore.collection('checkin_requests').add(checkInData);

      // Envoyer une notification à l'administration
      await _firestore.collection('notifications').add({
        'type': 'checkin_request',
        'title': 'Nouvelle demande de check-in',
        'message': '${userData['name'] ?? user.email} a demandé à effectuer un check-in',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'priority': 'high',
      });

      // Réinitialiser le formulaire
      _idNumberController.clear();
      _specialRequestsController.clear();
      setState(() {
        _showCheckInForm = false;
        _checkInWithoutReservation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande de check-in envoyée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi de la demande: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitCheckOutRequest(Map<String, dynamic> reservation) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Récupérer les informations utilisateur depuis Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final checkOutData = {
        'clientName': userData['name'] ?? '',
        'clientEmail': user.email ?? '',
        'clientPhone': userData['phone'] ?? '',
        'reservationId': reservation['id'],
        'roomNumber': reservation['roomNumber'] ?? 'Non attribué',
        'roomType': reservation['roomType'] ?? 'Chambre',
        'paymentMethod': _selectedPaymentMethod,
        'totalAmount': reservation['totalAmount'] ?? reservation['price'] ?? 0,
        'feedback': _feedbackController.text,
        'checkOutDate': FieldValue.serverTimestamp(),
        'status': 'pending',
        'userId': user.uid,
        'userEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Enregistrer la demande de check-out
      await _firestore.collection('checkout_requests').add(checkOutData);

      // Envoyer une notification à l'administration
      await _firestore.collection('notifications').add({
        'type': 'checkout_request',
        'title': 'Nouvelle demande de check-out',
        'message': '${userData['name'] ?? user.email} a demandé à effectuer un check-out',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'priority': 'high',
      });

      // Réinitialiser le formulaire
      _feedbackController.clear();
      setState(() {
        _showCheckOutForm = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande de check-out envoyée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi de la demande: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    final isStaff = _userRole == 'admin' || _userRole == 'staff';

    return Scaffold(
      appBar: AppBar(
        title: Text(isStaff ? 'Gestion des Check-in/Check-out' : 'Check-in/Check-out'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        leading: (_showCheckInForm || _showCheckOutForm) && !isWeb
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showCheckInForm = false;
                    _showCheckOutForm = false;
                    _checkInWithoutReservation = false;
                  });
                },
              )
            : null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F0E5), Color(0xFFFDF8F3)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF9B4610)))
            : _hasIndexError
                ? SingleChildScrollView(child: _buildIndexErrorWidget(isWeb))
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
                              onPressed: _loadReservations,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9B4610),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _showCheckInForm
                        ? _buildCheckInForm(isWeb, !_checkInWithoutReservation && _hasActiveReservation)
                        : _showCheckOutForm
                            ? _buildCheckOutForm(isWeb)
                            : SingleChildScrollView(child: _buildMainOptions(isWeb, isStaff)),
      ),
    );
  }

  Widget _buildIndexErrorWidget(bool isWeb) {
    return Padding(
      padding: EdgeInsets.all(isWeb ? 40.0 : 20.0),
      child: Center(
        child: Container(
          constraints: isWeb ? const BoxConstraints(maxWidth: 600) : null,
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
                'Pour afficher vos réservations, une configuration technique est nécessaire.',
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
                        'Les réservations ont bien été enregistrées',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Même si les données ne s\'affichent pas actuellement, soyez assuré que les réservations ont été enregistrées avec succès.',
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9B4610),
                                foregroundColor: Colors.white,
                              ),
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
                onPressed: _loadReservations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B4610),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 24 : 16,
                    vertical: isWeb ? 16 : 12,
                  ),
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainOptions(bool isWeb, bool isStaff) {
    // Débogage pour vérifier les valeurs des variables
    print('_hasActiveReservation: $_hasActiveReservation');
    print('_hasCheckedInReservation: $_hasCheckedInReservation');
    print('Nombre de réservations: ${_reservations.length}');
    for (var reservation in _reservations) {
      print('Réservation: ${reservation['id']}, Statut: ${reservation['status']}');
    }

    return Padding(
      padding: EdgeInsets.all(isWeb ? 40.0 : 20.0),
      child: Center(
        child: Container(
          constraints: isWeb ? const BoxConstraints(maxWidth: 600) : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hotel, size: 80, color: Color(0xFF9B4610)),
              const SizedBox(height: 20),
              const Text(
                'Check-in / Check-out',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choisissez une option pour continuer',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              
              // Toujours afficher l'option de check-in sans réservation
              _buildOptionCard(
                context,
                Icons.person_add,
                'Check-in sans réservation',
                'Je n\'ai pas de réservation et je souhaite effectuer un check-in',
                const Color(0xFF264653),
                () {
                  setState(() {
                    _showCheckInForm = true;
                    _checkInWithoutReservation = true;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Afficher le check-in avec réservation seulement si l'utilisateur a une réservation active
              // MODIFICATION: Afficher même si _hasActiveReservation est false pour le débogage
              _buildOptionCard(
                context,
                Icons.login,
                'Check-in avec réservation',
                'J\'ai déjà une réservation et je souhaite effectuer mon check-in',
                const Color(0xFF2A9D8F),
                () {
                  setState(() {
                    _showCheckInForm = true;
                    _checkInWithoutReservation = false;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Afficher le check-out seulement si l'utilisateur a une réservation avec statut checked-in
              // MODIFICATION: Afficher même si _hasCheckedInReservation est false pour le débogage
              _buildOptionCard(
                context,
                Icons.logout,
                'Check-out',
                'Effectuer mon check-out et régler ma facture',
                const Color(0xFFE76F51),
                () {
                  setState(() {
                    _showCheckOutForm = true;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Ajouter un bouton de débogage pour recharger les réservations
              if (!isStaff) // Seulement pour les clients
                ElevatedButton(
                  onPressed: _loadReservations,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Actualiser les réservations'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, IconData icon, String title, String description, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInForm(bool isWeb, bool hasReservation) {
    final user = _auth.currentUser;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWeb)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showCheckInForm = false;
                  _checkInWithoutReservation = false;
                });
              },
            ),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasReservation ? 'Check-in avec réservation' : 'Check-in sans réservation',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasReservation 
                      ? 'Veuillez confirmer votre identité pour compléter votre check-in'
                      : 'Veuillez fournir vos informations d\'identité et choisir votre chambre',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  
                  // Détails de la réservation si applicable
                  if (hasReservation && _reservations.isNotEmpty) ...[
                    const Text(
                      'Détails de la réservation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.room, color: Colors.grey),
                      title: const Text('Type de chambre'),
                      subtitle: Text(_reservations.first['roomType']?.toString() ?? 'Non spécifié'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.attach_money, color: Colors.grey),
                      title: const Text('Prix'),
                      subtitle: Text('${_reservations.first['price'] ?? _roomPrices[_reservations.first['roomType']] ?? 0} FCFA'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.grey),
                      title: const Text('Date d\'arrivée'),
                      subtitle: Text(_formatDate(_reservations.first['checkInDate'])),
                    ),
                    ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.grey),
                      title: const Text('Date de départ'),
                      subtitle: Text(_formatDate(_reservations.first['checkOutDate'])),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Sélection du type de chambre (uniquement pour check-in sans réservation)
                  if (!hasReservation) ...[
                    const Text(
                      'Sélection de la chambre',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedRoomType,
                      items: _roomPrices.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text('${entry.key} - ${entry.value} FCFA'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRoomType = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Type de chambre *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Afficher le prix de la chambre sélectionnée
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_money, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Prix: ${_roomPrices[_selectedRoomType]} FCFA',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Pièce d'identité
                  const Text(
                    'Informations d\'identité',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedIdType,
                    items: ['Carte d\'identité', 'Passeport', 'Permis de conduire', 'Autre']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedIdType = value!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Type de pièce *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _idNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de la pièce *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  // Demandes spéciales
                  const SizedBox(height: 20),
                  const Text(
                    'Demandes spéciales',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _specialRequestsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Demandes particulières (optionnel)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _submitCheckInRequest(hasReservation, hasReservation && _reservations.isNotEmpty ? _reservations.first : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B4610),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Soumettre la demande de check-in',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckOutForm(bool isWeb) {
    final user = _auth.currentUser;
    final Map<String, dynamic> reservation = _reservations.isNotEmpty ? _reservations.first : <String, dynamic>{};

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWeb)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showCheckOutForm = false;
                });
              },
            ),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Check-out',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Finalisez votre séjour et réglez votre facture',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  
                  // Informations de la réservation
                  const Text(
                    'Résumé de votre séjour',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.meeting_room, color: Colors.grey),
                    title: const Text('Chambre'),
                    subtitle: Text(reservation['roomNumber']?.toString() ?? 'Non attribué'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.room, color: Colors.grey),
                    title: const Text('Type de chambre'),
                    subtitle: Text(reservation['roomType']?.toString() ?? 'Non spécifié'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.grey),
                    title: const Text('Date d\'arrivée'),
                    subtitle: Text(_formatDate(reservation['checkInDate'])),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.grey),
                    title: const Text('Date de départ'),
                    subtitle: Text(_formatDate(reservation['checkOutDate'])),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people, color: Colors.grey),
                    title: const Text('Nombre de personnes'),
                    subtitle: Text(reservation['guests']?.toString() ?? '1'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_money, color: Colors.grey),
                    title: const Text('Montant total'),
                    subtitle: Text('${reservation['totalAmount'] ?? reservation['price'] ?? 0} FCFA'),
                  ),
                  
                  // Méthode de paiement
                  const SizedBox(height: 20),
                  const Text(
                    'Méthode de paiement',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    items: ['Espèces', 'Carte bancaire', 'Mobile Money', 'Virement', 'Autre']
                        .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Comment souhaitez-vous payer? *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  // Feedback
                  const SizedBox(height: 20),
                  const Text(
                    'Votre feedback',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Partagez votre expérience (optionnel)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _submitCheckOutRequest(reservation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B4610),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Confirmer le check-out',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
    } else if (timestamp is DateTime) {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    }
    return 'Date inconnue';
  }
}