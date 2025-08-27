// TODO Implement this library.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class RatingPage extends StatefulWidget {
  const RatingPage({super.key});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _completedStays = [];
  bool _isLoading = true;
  int _selectedStayIndex = -1;
  double _roomRating = 0;
  double _serviceRating = 0;
  double _cleanlinessRating = 0;
  String _comment = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCompletedStays();
  }

  Future<void> _loadCompletedStays() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'checked-out')
          .where('rated', isEqualTo: false)
          .orderBy('checkOutDate', descending: true)
          .get();

      setState(() {
        _completedStays = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur de chargement des séjours: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRating() async {
    if (_selectedStayIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un séjour à noter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_roomRating == 0 || _serviceRating == 0 || _cleanlinessRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez donner une note dans toutes les catégories'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final stay = _completedStays[_selectedStayIndex];
      final overallRating = (_roomRating + _serviceRating + _cleanlinessRating) / 3;

      // Enregistrer l'avis
      await _firestore.collection('ratings').add({
        'reservationId': stay['id'],
        'userId': _auth.currentUser!.uid,
        'userEmail': _auth.currentUser!.email,
        'roomType': stay['roomType'],
        'roomNumber': stay['roomNumber'],
        'roomRating': _roomRating,
        'serviceRating': _serviceRating,
        'cleanlinessRating': _cleanlinessRating,
        'overallRating': overallRating,
        'comment': _comment,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Marquer la réservation comme notée
      await _firestore.collection('reservations').doc(stay['id']).update({
        'rated': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci pour votre avis !'),
          backgroundColor: Colors.green,
        ),
      );

      // Réinitialiser le formulaire
      setState(() {
        _selectedStayIndex = -1;
        _roomRating = 0;
        _serviceRating = 0;
        _cleanlinessRating = 0;
        _comment = '';
      });

      // Recharger les séjours
      _loadCompletedStays();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi de l\'avis: $e'),
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
        title: const Text('Noter mon séjour'),
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
            : _completedStays.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucun séjour à noter',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Vous n\'avez aucun séjour terminé à évaluer pour le moment',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(isWeb ? 40.0 : 16.0),
                    child: isWeb
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: _buildStaysList(isWeb),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: _buildRatingForm(isWeb),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildStaysList(isWeb),
                              const SizedBox(height: 24),
                              _buildRatingForm(isWeb),
                            ],
                          ),
                  ),
      ),
    );
  }

  Widget _buildStaysList(bool isWeb) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mes séjours terminés',
              style: TextStyle(
                fontSize: isWeb ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4A2A10),
              ),
            ),
            const SizedBox(height: 16),
            ..._completedStays.asMap().entries.map((entry) {
              final index = entry.key;
              final stay = entry.value;
              final isSelected = _selectedStayIndex == index;

              final checkInDate = stay['checkInDate'] is Timestamp
                  ? (stay['checkInDate'] as Timestamp).toDate()
                  : DateTime.now();
              final checkOutDate = stay['checkOutDate'] is Timestamp
                  ? (stay['checkOutDate'] as Timestamp).toDate()
                  : DateTime.now();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF9B4610).withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF9B4610)
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    stay['roomType'] ?? 'Chambre',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFF9B4610)
                          : const Color(0xFF4A2A10),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Chambre: ${stay['roomNumber'] ?? 'Non attribué'}'),
                      Text(
                          'Du ${_formatDate(checkInDate)} au ${_formatDate(checkOutDate)}'),
                    ],
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF9B4610))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedStayIndex = index;
                    });
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingForm(bool isWeb) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Donnez votre avis',
              style: TextStyle(
                fontSize: isWeb ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4A2A10),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Votre feedback nous aide à améliorer nos services',
              style: TextStyle(
                color: Color(0xFF6D5D4F),
              ),
            ),
            const SizedBox(height: 24),
            _buildRatingCategory('Confort de la chambre', _roomRating, (rating) {
              setState(() => _roomRating = rating);
            }),
            const SizedBox(height: 20),
            _buildRatingCategory('Qualité du service', _serviceRating, (rating) {
              setState(() => _serviceRating = rating);
            }),
            const SizedBox(height: 20),
            _buildRatingCategory('Propreté', _cleanlinessRating, (rating) {
              setState(() => _cleanlinessRating = rating);
            }),
            const SizedBox(height: 24),
            const Text(
              'Commentaire (optionnel)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A2A10),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Partagez votre expérience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => _comment = value,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
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
                        'Envoyer mon avis',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCategory(String title, double rating, Function(double) onRatingUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A2A10),
          ),
        ),
        const SizedBox(height: 8),
        RatingBar.builder(
          initialRating: rating,
          minRating: 1,
          direction: Axis.horizontal,
          allowHalfRating: true,
          itemCount: 5,
          itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
          itemBuilder: (context, _) => const Icon(
            Icons.star,
            color: Colors.amber,
          ),
          onRatingUpdate: onRatingUpdate,
        ),
        const SizedBox(height: 4),
        Text(
          rating == 0 ? 'Aucune note' : '${rating.toStringAsFixed(1)}/5',
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}