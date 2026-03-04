// ============================================================
// check_in_out_page.dart
// Page de check-in et check-out pour le client.
// Le client remplit un formulaire, la demande est envoyée
// à la réception qui valide et attribue une chambre.
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CheckInOutPage extends StatefulWidget {
  const CheckInOutPage({super.key});

  @override
  State<CheckInOutPage> createState() => _CheckInOutPageState();
}

class _CheckInOutPageState extends State<CheckInOutPage>
    with SingleTickerProviderStateMixin {
  // ── Couleurs ─────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  // ── Services ──────────────────────────────────────────────────────────────
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ── État de chargement ────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;

  // ── Informations utilisateur ──────────────────────────────────────────────
  Map<String, dynamic> _userData = {};
  String? _activeReservationId; // ID de la réservation confirmée
  Map<String, dynamic>? _activeReservation; // Données de la réservation active
  bool _hasCheckedIn = false; // Le client a-t-il déjà fait son check-in ?

  // ── Formulaire check-in ───────────────────────────────────────────────────
  final _idNumberCtrl = TextEditingController();
  final _specialRequestsCtrl = TextEditingController();
  String _selectedIdType = "Carte d'identité";
  String _selectedRoomType = 'Premium';
  bool _isSubmittingCheckIn = false;

  // ── Formulaire check-out ──────────────────────────────────────────────────
  final _feedbackCtrl = TextEditingController();
  String _selectedPayment = 'Espèces';
  bool _isSubmittingCheckOut = false;

  // ── Navigation interne ────────────────────────────────────────────────────
  // null = menu principal | 'checkin_with' | 'checkin_without' | 'checkout'
  String? _currentView;

  // Prix des types de chambres en FCFA
  static const _roomPrices = {
    'Standard': 35000,
    'Premium': 48580,
    'Prestige': 58580,
    'Deluxe': 78580,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _idNumberCtrl.dispose();
    _specialRequestsCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  // ── Chargement des données ────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Utilisateur non connecté';
          _isLoading = false;
        });
        return;
      }

      // Charge le profil utilisateur
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _userData = userDoc.data()!;
      }

      // Cherche une réservation confirmée ou en check-in pour ce client
      final reservSnap = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .where('statut', whereIn: ['confirmée', 'checkin'])
          .limit(1)
          .get();

      if (reservSnap.docs.isNotEmpty) {
        _activeReservationId = reservSnap.docs.first.id;
        _activeReservation = {
          'id': _activeReservationId,
          ...reservSnap.docs.first.data(),
        };
        _hasCheckedIn =
            reservSnap.docs.first.data()['statut'] == 'checkin';
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement : $e';
        _isLoading = false;
      });
    }
  }

  // ── Soumission demande check-in ───────────────────────────────────────────

  Future<void> _submitCheckIn({required bool hasReservation}) async {
    if (_idNumberCtrl.text.trim().isEmpty) {
      _showSnack(
          'Veuillez saisir votre numéro de pièce d\'identité.',
          Colors.orange);
      return;
    }

    setState(() => _isSubmittingCheckIn = true);

    try {
      final user = _auth.currentUser!;
      final batch = _firestore.batch();

      // Données communes du check-in
      final checkInData = {
        'userId': user.uid,
        'userEmail': user.email,
        'userName': _userData['name'] ?? user.email,
        'userPhone': _userData['phone'] ?? '',
        'idType': _selectedIdType,
        'idNumber': _idNumberCtrl.text.trim(),
        'specialRequests': _specialRequestsCtrl.text.trim(),
        'hasReservation': hasReservation,
        'reservationId': hasReservation ? _activeReservationId : null,
        'roomType': hasReservation
            ? (_activeReservation?['chambre'] ?? _selectedRoomType)
            : _selectedRoomType,
        'price': hasReservation
            ? (_activeReservation?['prixTotal'] ??
                _roomPrices[_selectedRoomType])
            : _roomPrices[_selectedRoomType],
        'status': 'pending', // La réception doit valider
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Enregistre la demande de check-in
      final checkInRef = _firestore.collection('checkin_requests').doc();
      batch.set(checkInRef, checkInData);

      // Notification pour la réception
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'type': 'checkin_request',
        'title': 'Nouvelle demande de check-in',
        'message':
            '${_userData['name'] ?? user.email} souhaite effectuer un check-in',
        'checkInId': checkInRef.id,
        'priority': 'high',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      await batch.commit();

      _idNumberCtrl.clear();
      _specialRequestsCtrl.clear();
      setState(() => _currentView = null);
      _showSnack(
          '✅ Demande envoyée ! La réception va vous prendre en charge.',
          Colors.green);
      _loadData(); // Recharge les données
    } catch (e) {
      _showSnack('Erreur : $e', Colors.red);
    } finally {
      setState(() => _isSubmittingCheckIn = false);
    }
  }

  // ── Soumission demande check-out ──────────────────────────────────────────

  Future<void> _submitCheckOut() async {
    if (_activeReservation == null) {
      _showSnack('Aucune réservation active trouvée.', Colors.orange);
      return;
    }

    setState(() => _isSubmittingCheckOut = true);

    try {
      final user = _auth.currentUser!;
      final batch = _firestore.batch();

      // Enregistre la demande de check-out
      final checkOutRef =
          _firestore.collection('checkout_requests').doc();
      batch.set(checkOutRef, {
        'userId': user.uid,
        'userEmail': user.email,
        'userName': _userData['name'] ?? user.email,
        'reservationId': _activeReservationId,
        'roomNumber': _activeReservation?['chambre'] ?? 'Non attribué',
        'paymentMethod': _selectedPayment,
        'totalAmount':
            _activeReservation?['prixTotal'] ?? 0,
        'feedback': _feedbackCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notification pour la réception
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'type': 'checkout_request',
        'title': 'Nouvelle demande de check-out',
        'message':
            '${_userData['name'] ?? user.email} souhaite effectuer un check-out',
        'checkOutId': checkOutRef.id,
        'priority': 'high',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      await batch.commit();

      _feedbackCtrl.clear();
      setState(() => _currentView = null);
      _showSnack(
          '✅ Demande de check-out envoyée ! Merci pour votre séjour.',
          Colors.green);
    } catch (e) {
      _showSnack('Erreur : $e', Colors.red);
    } finally {
      setState(() => _isSubmittingCheckOut = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text(_currentView == null
            ? 'Check-in / Check-out'
            : _currentView == 'checkout'
                ? 'Check-out'
                : 'Check-in'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _currentView != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () =>
                    setState(() => _currentView = null),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? _buildError(isWeb)
              : _currentView == null
                  ? _buildMainMenu(isWeb)
                  : _currentView == 'checkout'
                      ? _buildCheckOutForm(isWeb)
                      : _buildCheckInForm(isWeb),
    );
  }

  // ── Menu principal ────────────────────────────────────────────────────────

  Widget _buildMainMenu(bool isWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 40 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // En-tête illustré
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _dark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.hotel_rounded,
                        size: 52, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      'Check-in / Check-out',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bonjour ${_userData['name'] ?? ''} 👋',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Statut de réservation active
              if (_activeReservation != null)
                _buildActiveReservationCard(),
              if (_activeReservation != null) const SizedBox(height: 20),

              // Options
              _buildOptionTile(
                icon: Icons.person_add_rounded,
                title: 'Check-in sans réservation',
                subtitle:
                    'Je n\'ai pas de réservation préalable',
                color: const Color(0xFF264653),
                onTap: () =>
                    setState(() => _currentView = 'checkin_without'),
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.login_rounded,
                title: 'Check-in avec réservation',
                subtitle: _activeReservation != null
                    ? 'Réservation active trouvée ✅'
                    : 'J\'ai une réservation confirmée',
                color: const Color(0xFF2A9D8F),
                onTap: () =>
                    setState(() => _currentView = 'checkin_with'),
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.logout_rounded,
                title: 'Check-out',
                subtitle: _hasCheckedIn
                    ? 'Finaliser mon séjour ✅'
                    : 'Quitter l\'hôtel',
                color: const Color(0xFFE76F51),
                onTap: () =>
                    setState(() => _currentView = 'checkout'),
              ),
              const SizedBox(height: 20),

              // Bouton actualiser
              TextButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Actualiser'),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Carte de réservation active
  Widget _buildActiveReservationCard() {
    final res = _activeReservation!;
    final chambre = res['chambre'] ?? 'Non attribuée';
    final statut = res['statut'] ?? '';
    final arrival = _formatDate(res['dateArrivee']);
    final departure = _formatDate(res['dateDepart']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: Colors.green, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Réservation active',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statut,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Chambre : $chambre  •  $arrival → $departure',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tuile d'option du menu
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.07),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Formulaire check-in ───────────────────────────────────────────────────

  Widget _buildCheckInForm(bool isWeb) {
    final hasReservation = _currentView == 'checkin_with';
    final hasActiveResv =
        hasReservation && _activeReservation != null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre
              _buildSectionTitle(
                hasReservation
                    ? 'Check-in avec réservation'
                    : 'Check-in sans réservation',
                Icons.login_rounded,
              ),
              const SizedBox(height: 20),

              // Si réservation active, affiche les détails
              if (hasActiveResv)
                _buildReservationSummary(),

              // Si sans réservation, choix du type de chambre
              if (!hasActiveResv) ...[
                _buildLabel('Type de chambre souhaité'),
                const SizedBox(height: 8),
                _buildDropdown(
                  value: _selectedRoomType,
                  items: _roomPrices.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(
                          '${e.key} – ${NumberFormat('#,###', 'fr_FR').format(e.value)} FCFA'),
                    );
                  }).toList(),
                  onChanged: (v) =>
                      setState(() => _selectedRoomType = v!),
                ),
                const SizedBox(height: 16),
                // Affiche le prix sélectionné
                _buildPriceBanner(_selectedRoomType),
              ],

              const SizedBox(height: 20),

              // Pièce d'identité
              _buildLabel('Type de pièce d\'identité *'),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedIdType,
                items: [
                  "Carte d'identité",
                  'Passeport',
                  'Permis de conduire',
                  'Autre',
                ]
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedIdType = v!),
              ),
              const SizedBox(height: 14),
              _buildLabel('Numéro de la pièce *'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _idNumberCtrl,
                hint: 'Ex: AB123456',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),

              // Demandes spéciales
              _buildLabel('Demandes spéciales (optionnel)'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _specialRequestsCtrl,
                hint:
                    'Chambre calme, allergie, lit bébé…',
                icon: Icons.note_alt_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 28),

              // Bouton soumettre
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmittingCheckIn
                      ? null
                      : () => _submitCheckIn(
                          hasReservation: hasActiveResv),
                  icon: _isSubmittingCheckIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmittingCheckIn
                        ? 'Envoi…'
                        : 'Envoyer la demande de check-in',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Formulaire check-out ──────────────────────────────────────────────────

  Widget _buildCheckOutForm(bool isWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                  'Finaliser votre séjour', Icons.logout_rounded),
              const SizedBox(height: 20),

              // Résumé du séjour si disponible
              if (_activeReservation != null)
                _buildReservationSummary(),

              const SizedBox(height: 20),

              // Méthode de paiement
              _buildLabel('Méthode de paiement *'),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedPayment,
                items: [
                  'Espèces',
                  'Carte bancaire',
                  'Mobile Money',
                  'Virement',
                ]
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedPayment = v!),
              ),
              const SizedBox(height: 14),

              // Feedback
              _buildLabel(
                  'Partagez votre expérience (optionnel)'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _feedbackCtrl,
                hint:
                    'Votre avis nous aide à nous améliorer…',
                icon: Icons.star_outline_rounded,
                maxLines: 4,
              ),
              const SizedBox(height: 28),

              // Bouton checkout
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmittingCheckOut
                      ? null
                      : _submitCheckOut,
                  icon: _isSubmittingCheckOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Icon(Icons.logout_rounded,
                          size: 18),
                  label: Text(
                    _isSubmittingCheckOut
                        ? 'Envoi…'
                        : 'Confirmer le check-out',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE76F51),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets utilitaires ───────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: _primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: _dark,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            vertical: 14, horizontal: 14),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _primary),
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPriceBanner(String type) {
    final price = _roomPrices[type] ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_money_rounded,
              color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            'Prix : ${NumberFormat('#,###', 'fr_FR').format(price)} FCFA / nuit',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationSummary() {
    final res = _activeReservation!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hotel_rounded,
                  color: _primary, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Détails de la réservation',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(Icons.meeting_room_rounded, 'Chambre',
              res['chambre']?.toString() ?? 'Non attribuée'),
          _infoRow(Icons.calendar_today_rounded, 'Arrivée',
              _formatDate(res['dateArrivee'])),
          _infoRow(Icons.calendar_today_rounded, 'Départ',
              _formatDate(res['dateDepart'])),
          _infoRow(
            Icons.attach_money_rounded,
            'Montant total',
            '${NumberFormat('#,###', 'fr_FR').format(res['prixTotal'] ?? 0)} FCFA',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            '$label : ',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isWeb) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // Convertit un Timestamp ou String en format lisible
  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(value.toDate());
    } else if (value is String) {
      try {
        return DateFormat('dd/MM/yyyy')
            .format(DateTime.parse(value));
      } catch (_) {}
    }
    return 'Non défini';
  }
}