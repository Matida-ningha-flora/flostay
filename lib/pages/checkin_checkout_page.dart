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
  bool _hasIndexError = false;
  String _indexUrl = '';
  String _userRole = 'client';
  bool _showCheckInForm = false;

  // Contrôleurs pour le formulaire de check-in manuel
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _roomTypeController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController();
  final TextEditingController _nightsController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  DateTime? _checkInDate;
  DateTime? _checkOutDate;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _roomNumberController.dispose();
    _roomTypeController.dispose();
    _guestsController.dispose();
    _nightsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
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
      _loadCheckInOutData();
    } catch (e) {
      print("Erreur de chargement du rôle utilisateur: $e");
      _loadCheckInOutData();
    }
  }

  Future<void> _loadCheckInOutData() async {
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
        snapshot = await _firestore
            .collection('reservations')
            .orderBy('checkInDate', descending: false)
            .get();
      } else {
        snapshot = await _firestore
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .orderBy('checkInDate', descending: false)
            .get();
      }

      setState(() {
        _reservations = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();

        _reservations = _reservations.where((reservation) {
          final status = reservation['status'] ?? '';
          return status != 'cancelled' && status != 'checked-out';
        }).toList();

        _isLoading = false;
        _hasIndexError = false;
      });
    } catch (e) {
      print("Erreur de chargement des données check-in/out: $e");

      if (e.toString().contains('index') && e.toString().contains('create_composite')) {
        final regex = RegExp(r'https://console\.firebase\.google\.com[^\s]+');
        final match = regex.firstMatch(e.toString());

        setState(() {
          _isLoading = false;
          _hasIndexError = true;
          _errorMessage = 'Configuration requise pour afficher les données de check-in/out';
          if (match != null) {
            _indexUrl = match.group(0)!;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de chargement: $e';
          _hasIndexError = false;
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

  Future<void> _manualCheckIn() async {
    if (_clientNameController.text.isEmpty || _roomNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
      );
      return;
    }

    try {
      final newReservation = {
        'clientName': _clientNameController.text,
        'clientEmail': _clientEmailController.text,
        'clientPhone': _clientPhoneController.text,
        'roomNumber': _roomNumberController.text,
        'roomType': _roomTypeController.text.isNotEmpty ? _roomTypeController.text : 'Standard',
        'guests': int.tryParse(_guestsController.text) ?? 1,
        'nights': int.tryParse(_nightsController.text) ?? 1,
        'price': int.tryParse(_priceController.text) ?? 0,
        'checkInDate': _checkInDate ?? DateTime.now(),
        'checkOutDate': _checkOutDate ?? DateTime.now().add(const Duration(days: 1)),
        'status': 'checked-in',
        'actualCheckIn': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isManualCheckIn': true,
      };

      await _firestore.collection('reservations').add(newReservation);

      // Réinitialiser le formulaire
      _clientNameController.clear();
      _clientEmailController.clear();
      _clientPhoneController.clear();
      _roomNumberController.clear();
      _roomTypeController.clear();
      _guestsController.clear();
      _nightsController.clear();
      _priceController.clear();
      setState(() {
        _checkInDate = null;
        _checkOutDate = null;
        _showCheckInForm = false;
      });

      // Recharger les données
      _loadCheckInOutData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in manuel effectué avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du check-in manuel: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          // Définir automatiquement la date de check-out (check-in + 1 jour)
          _checkOutDate = picked.add(const Duration(days: 1));
          _nightsController.text = '1';
        } else {
          _checkOutDate = picked;
          // Calculer le nombre de nuits
          if (_checkInDate != null) {
            final nights = _checkOutDate!.difference(_checkInDate!).inDays;
            _nightsController.text = nights.toString();
          }
        }
      });
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
    } else if (timestamp is DateTime) {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    }
    return 'Date inconnue';
  }

  String _formatPrice(dynamic price) {
    if (price is int || price is double) {
      return '$price FCFA';
    } else if (price is String) {
      return '$price FCFA';
    }
    return '0 FCFA';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'checked-in':
        return Colors.blue;
      case 'checked-out':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmée';
      case 'checked-in':
        return 'En cours';
      case 'checked-out':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      case 'pending':
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;
    final isStaff = _userRole == 'admin' || _userRole == 'staff';

    return Scaffold(
      appBar: AppBar(
        title: Text(isStaff ? 'Gestion des Check-in/Check-out' : 'Mes Check-in/Check-out'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        actions: isStaff
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _showCheckInForm = !_showCheckInForm;
                    });
                  },
                  tooltip: 'Nouveau check-in manuel',
                ),
              ]
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
            ? const Center(child: CircularProgressIndicator())
            : _hasIndexError
                ? _buildIndexErrorWidget(isWeb)
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
                              onPressed: _loadCheckInOutData,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _showCheckInForm
                        ? _buildCheckInForm(isWeb)
                        : _reservations.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.calendar_today, size: 60, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      isStaff
                                          ? 'Aucune réservation nécessitant un check-in/out'
                                          : 'Aucune de vos réservations ne nécessite un check-in/out',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isStaff
                                          ? 'Toutes les réservations sont traitées ou il n\'y a pas de réservation en attente'
                                          : 'Toutes vos réservations sont traitées ou vous n\'avez pas de réservation en attente',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
                                child: isWeb
                                    ? _buildWebLayout()
                                    : ListView.builder(
                                        itemCount: _reservations.length,
                                        itemBuilder: (context, index) {
                                          return _buildReservationCard(_reservations[index], false);
                                        },
                                      ),
                              ),
      ),
    );
  }

  Widget _buildCheckInForm(bool isWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nouveau Check-in Manuel',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du client *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email du client',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone du client',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _roomNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de chambre *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _roomTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Type de chambre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _guestsController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de personnes',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nightsController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de nuits',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Prix total (FCFA)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text(_checkInDate == null
                          ? 'Date d\'arrivée *'
                          : 'Arrivée: ${DateFormat('dd/MM/yyyy').format(_checkInDate!)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      title: Text(_checkOutDate == null
                          ? 'Date de départ *'
                          : 'Départ: ${DateFormat('dd/MM/yyyy').format(_checkOutDate!)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showCheckInForm = false;
                      });
                    },
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _manualCheckIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B4610),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Enregistrer le check-in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    final isStaff = _userRole == 'admin' || _userRole == 'staff';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: isStaff
            ? const [
                DataColumn(label: Text('Client')),
                DataColumn(label: Text('Chambre')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Arrivée')),
                DataColumn(label: Text('Départ')),
                DataColumn(label: Text('Personnes')),
                DataColumn(label: Text('Prix')),
                DataColumn(label: Text('Statut')),
                DataColumn(label: Text('Actions')),
              ]
            : const [
                DataColumn(label: Text('Chambre')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Arrivée')),
                DataColumn(label: Text('Départ')),
                DataColumn(label: Text('Personnes')),
                DataColumn(label: Text('Prix')),
                DataColumn(label: Text('Statut')),
                DataColumn(label: Text('Actions')),
              ],
        rows: _reservations.map((reservation) {
          final cells = isStaff
              ? [
                  DataCell(Text(reservation['clientName'] ?? 
                              reservation['userEmail'] ?? 
                              reservation['userId'] ?? 'Inconnu')),
                  DataCell(Text(reservation['roomNumber']?.toString() ?? 'Non attribué')),
                  DataCell(Text(reservation['roomType'] ?? 'Chambre')),
                  DataCell(Text(_formatTimestamp(reservation['checkInDate']))),
                  DataCell(Text(_formatTimestamp(reservation['checkOutDate']))),
                  DataCell(Text(reservation['guests']?.toString() ?? '1')),
                  DataCell(Text(_formatPrice(reservation['totalAmount'] ?? reservation['price'] ?? 0))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(reservation['status'] ?? 'pending'),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusText(reservation['status'] ?? 'pending'),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(_buildActionButton(reservation)),
                ]
              : [
                  DataCell(Text(reservation['roomNumber']?.toString() ?? 'Non attribué')),
                  DataCell(Text(reservation['roomType'] ?? 'Chambre')),
                  DataCell(Text(_formatTimestamp(reservation['checkInDate']))),
                  DataCell(Text(_formatTimestamp(reservation['checkOutDate']))),
                  DataCell(Text(reservation['guests']?.toString() ?? '1')),
                  DataCell(Text(_formatPrice(reservation['totalAmount'] ?? reservation['price'] ?? 0))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(reservation['status'] ?? 'pending'),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusText(reservation['status'] ?? 'pending'),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(_buildActionButton(reservation)),
                ];

          return DataRow(cells: cells);
        }).toList(),
      ),
    );
  }

  Widget _buildActionButton(Map<String, dynamic> reservation) {
    final status = reservation['status'] ?? 'pending';
    final isStaff = _userRole == 'admin' || _userRole == 'staff';

    if (status == 'confirmed') {
      return ElevatedButton(
        onPressed: () => _processCheckIn(reservation),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text('Check-in'),
      );
    } else if (status == 'checked-in') {
      return ElevatedButton(
        onPressed: () => _processCheckOut(reservation),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        child: const Text('Check-out'),
      );
    } else if (status == 'pending') {
      return isStaff
          ? ElevatedButton(
              onPressed: () => _confirmReservation(reservation),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmer'),
            )
          : const Text(
              'En attente de confirmation',
              style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
            );
    }

    return const SizedBox.shrink();
  }

  void _processCheckIn(Map<String, dynamic> reservation) async {
    try {
      await _firestore.collection('reservations').doc(reservation['id']).update(
        {'status': 'checked-in', 'actualCheckIn': FieldValue.serverTimestamp()},
      );

      _loadCheckInOutData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in effectué avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du check-in: $e')),
      );
    }
  }

  void _processCheckOut(Map<String, dynamic> reservation) async {
    try {
      await _firestore.collection('reservations').doc(reservation['id']).update(
        {
          'status': 'checked-out',
          'actualCheckOut': FieldValue.serverTimestamp(),
        },
      );

      _loadCheckInOutData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-out effectué avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du check-out: $e')),
      );
    }
  }

  void _confirmReservation(Map<String, dynamic> reservation) async {
    try {
      await _firestore.collection('reservations').doc(reservation['id']).update(
        {'status': 'confirmed'},
      );

      _loadCheckInOutData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réservation confirmée avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la confirmation: $e')),
      );
    }
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
                'Pour afficher vos données de check-in/check-out, une configuration technique est nécessaire.',
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
                onPressed: _loadCheckInOutData,
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

  Widget _buildReservationCard(Map<String, dynamic> reservation, bool isWeb) {
    final checkInDate = reservation['checkInDate'];
    final checkOutDate = reservation['checkOutDate'];
    final status = reservation['status'] ?? 'pending';
    final roomNumber = reservation['roomNumber'] ?? 'Non attribué';
    final totalAmount = reservation['totalAmount'] ?? reservation['price'] ?? 0;
    final isStaff = _userRole == 'admin' || _userRole == 'staff';

    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: isWeb ? 20.0 : 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 20.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isStaff) ...[
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Client: ${reservation['clientName'] ?? reservation['userEmail'] ?? reservation['userId'] ?? 'Inconnu'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reservation['roomType'] ?? 'Chambre',
                  style: TextStyle(
                    fontSize: isWeb ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A2A10),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(status),
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
            Row(
              children: [
                Icon(Icons.meeting_room, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Chambre: $roomNumber',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Arrivée: ${_formatTimestamp(checkInDate)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Départ: ${_formatTimestamp(checkOutDate)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Personnes: ${reservation['guests'] ?? '1'}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatPrice(totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9B4610),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActionButton(reservation),
          ],
        ),
      ),
    );
  }
}