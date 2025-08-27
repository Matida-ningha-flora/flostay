import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ReservationFormPage extends StatefulWidget {
  final String roomTitle;
  final int roomPrice;

  const ReservationFormPage({
    super.key,
    required this.roomTitle,
    required this.roomPrice,
  });

  @override
  State<ReservationFormPage> createState() => _ReservationFormPageState();
}

class _ReservationFormPageState extends State<ReservationFormPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _checkInController = TextEditingController();
  final _checkOutController = TextEditingController();
  final _guestsController = TextEditingController(text: "1");
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardNameController = TextEditingController();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  int _currentStep = 0;
  int _nights = 1;
  int _totalAmount = 0;
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  String _selectedPaymentMethod = '';

  // Méthodes de paiement disponibles
  final List<String> _paymentMethods = [
    'Orange Money',
    'MTN Mobile Money',
    'Carte bancaire',
    'Espèces à l\'arrivée'
  ];

  @override
  void initState() {
    super.initState();
    _emailController.text = _auth.currentUser?.email ?? '';
    _calculateTotal();
  }

  void _calculateTotal() {
    if (_checkInDate != null && _checkOutDate != null) {
      _nights = _checkOutDate!.difference(_checkInDate!).inDays;
      if (_nights < 1) _nights = 1;
      _totalAmount = widget.roomPrice * _nights;
    } else {
      _totalAmount = widget.roomPrice;
    }
    setState(() {});
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn ? DateTime.now() : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      if (isCheckIn) {
        _checkInDate = picked;
        _checkInController.text = DateFormat('dd/MM/yyyy').format(picked);
        // Si la date de check-out est antérieure, on la met à jour
        if (_checkOutDate != null && _checkOutDate!.isBefore(picked.add(const Duration(days: 1)))) {
          _checkOutDate = picked.add(const Duration(days: 1));
          _checkOutController.text = DateFormat('dd/MM/yyyy').format(_checkOutDate!);
        }
      } else {
        if (_checkInDate != null && picked.isAfter(_checkInDate!)) {
          _checkOutDate = picked;
          _checkOutController.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("La date de départ doit être après la date d'arrivée"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      _calculateTotal();
    }
  }

  Future<void> _submitReservation() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      // Créer la réservation
      final reservationRef = await _firestore.collection('reservations').add({
        'userId': user.uid,
        'userName': _nameController.text,
        'userEmail': _emailController.text,
        'userPhone': _phoneController.text,
        'roomType': widget.roomTitle,
        'roomPrice': widget.roomPrice,
        'checkInDate': Timestamp.fromDate(_checkInDate!),
        'checkOutDate': Timestamp.fromDate(_checkOutDate!),
        'nights': _nights,
        'guests': int.parse(_guestsController.text),
        'totalAmount': _totalAmount,
        'paymentMethod': _selectedPaymentMethod,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Créer une notification pour l'administration
      await _firestore.collection('notifications').add({
        'type': 'reservation',
        'title': 'Nouvelle réservation',
        'message': '${_nameController.text} a réservé une ${widget.roomTitle} pour ${_checkInDate!.day}/${_checkInDate!.month}/${_checkInDate!.year}',
        'reservationId': reservationRef.id,
        'userId': user.uid,
        'userEmail': _emailController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Mettre à jour le profil utilisateur avec les informations
      await _firestore.collection('users').doc(user.uid).set({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Réservation effectuée avec succès !"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Rediriger vers la page d'accueil après un délai
      await Future.delayed(const Duration(seconds: 2));
      Navigator.popUntil(context, (route) => route.isFirst);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la réservation: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _checkInController.text.isEmpty ||
        _checkOutController.text.isEmpty ||
        _selectedPaymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez remplir tous les champs obligatoires"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_checkInDate == null || _checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner des dates valides"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  void _processPayment() {
    if (_selectedPaymentMethod == 'Carte bancaire') {
      if (_cardNumberController.text.isEmpty ||
          _cardExpiryController.text.isEmpty ||
          _cardCvvController.text.isEmpty ||
          _cardNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez remplir tous les détails de la carte"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Simulation de paiement
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Paiement"),
        content: Text(
          "Paiement de $_totalAmount FCFA effectué avec $_selectedPaymentMethod\n\n"
          "Cette fonctionnalité est une simulation. En production, vous intégreriez une vraie solution de paiement.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitReservation();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Réservation - ${widget.roomTitle}",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF9B4610),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep == 0 && _validateStep1()) {
              setState(() => _currentStep = 1);
            } else if (_currentStep == 1 && _validateStep2()) {
              setState(() => _currentStep = 2);
            } else if (_currentStep == 2) {
              _processPayment();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            } else {
              Navigator.pop(context);
            }
          },
          steps: [
            // Étape 1: Informations personnelles
            Step(
              title: const Text('Informations personnelles'),
              content: _buildPersonalInfoForm(),
              isActive: _currentStep >= 0,
            ),
            // Étape 2: Détails du séjour
            Step(
              title: const Text('Détails du séjour'),
              content: _buildStayDetailsForm(),
              isActive: _currentStep >= 1,
            ),
            // Étape 3: Paiement
            Step(
              title: const Text('Paiement'),
              content: _buildPaymentForm(),
              isActive: _currentStep >= 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoForm() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: "Nom complet *",
            prefixIcon: Icon(Icons.person, color: Color(0xFF9B4610)),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: "Numéro de téléphone *",
            prefixIcon: Icon(Icons.phone, color: Color(0xFF9B4610)),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: "Adresse email *",
            prefixIcon: Icon(Icons.email, color: Color(0xFF9B4610)),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildStayDetailsForm() {
    return Column(
      children: [
        // Informations sur la chambre
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8E9DD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.hotel, color: Color(0xFF9B4610)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.roomTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text("${widget.roomPrice} FCFA / nuit"),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Dates de séjour
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _checkInController,
                decoration: const InputDecoration(
                  labelText: "Date d'arrivée *",
                  prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF9B4610)),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _checkOutController,
                decoration: const InputDecoration(
                  labelText: "Date de départ *",
                  prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF9B4610)),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Nombre de personnes
        TextFormField(
          controller: _guestsController,
          decoration: const InputDecoration(
            labelText: "Nombre de personnes *",
            prefixIcon: Icon(Icons.people, color: Color(0xFF9B4610)),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) => _calculateTotal(),
        ),
        const SizedBox(height: 16),
        // Résumé du prix
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                "$_totalAmount FCFA",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9B4610),
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentForm() {
    return Column(
      children: [
        const Text(
          "Choisissez votre méthode de paiement",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._paymentMethods.map((method) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<String>(
              title: Text(method),
              value: method,
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                });
              },
            ),
          );
        }).toList(),
        
        // Formulaire pour carte bancaire
        if (_selectedPaymentMethod == 'Carte bancaire') ...[
          const SizedBox(height: 16),
          const Text(
            "Détails de la carte bancaire",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _cardNumberController,
            decoration: const InputDecoration(
              labelText: "Numéro de carte *",
              prefixIcon: Icon(Icons.credit_card, color: Color(0xFF9B4610)),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cardExpiryController,
                  decoration: const InputDecoration(
                    labelText: "MM/AA *",
                    prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF9B4610)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _cardCvvController,
                  decoration: const InputDecoration(
                    labelText: "CVV *",
                    prefixIcon: Icon(Icons.lock, color: Color(0xFF9B4610)),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _cardNameController,
            decoration: const InputDecoration(
              labelText: "Nom sur la carte *",
              prefixIcon: Icon(Icons.person, color: Color(0xFF9B4610)),
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        const Text(
          "Note: Cette fonctionnalité est une simulation. En production, vous intégreriez une vraie solution de paiement.",
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  bool _validateStep1() {
    if (_nameController.text.isEmpty || 
        _phoneController.text.isEmpty || 
        _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez remplir tous les champs obligatoires"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_checkInController.text.isEmpty || 
        _checkOutController.text.isEmpty || 
        _guestsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez remplir tous les champs obligatoires"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _guestsController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardNameController.dispose();
    super.dispose();
  }
}