// ============================================================
// parametres_page.dart (VERSION COMPLÈTE ET FONCTIONNELLE)
//
// Onglets :
// 1. Profil admin — modifier nom, téléphone, photo, réinitialiser MDP
// 2. Hôtel — nom, adresse, téléphone, email, description
// 3. Notifications — activer/désactiver push, email, SMS
// 4. Apparence — thème, langue
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({Key? key}) : super(key: key);

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);
  static const _bucket = 'profile-images';

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;

  // ── Profil admin ──────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _profileImageUrl;
  bool _uploadingImage = false;
  bool _savingProfile = false;

  // ── Paramètres hôtel ──────────────────────────────────────────────────────
  final _hotelNameCtrl = TextEditingController();
  final _hotelAdressCtrl = TextEditingController();
  final _hotelPhoneCtrl = TextEditingController();
  final _hotelEmailCtrl = TextEditingController();
  final _hotelDescCtrl = TextEditingController();
  bool _savingHotel = false;

  // ── Notifications ─────────────────────────────────────────────────────────
  bool _notifEnabled = true;
  bool _notifEmail = true;
  bool _notifSMS = false;
  bool _notifPush = true;
  bool _savingNotif = false;

  // ── Apparence ─────────────────────────────────────────────────────────────
  String _language = 'fr';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _hotelNameCtrl.dispose();
    _hotelAdressCtrl.dispose();
    _hotelPhoneCtrl.dispose();
    _hotelEmailCtrl.dispose();
    _hotelDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadHotelSettings(),
      _loadNotifSettings(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameCtrl.text = data['name'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _profileImageUrl = data['profileImage'];
    }
  }

  Future<void> _loadHotelSettings() async {
    final doc =
        await _firestore.collection('settings').doc('hotel').get();
    if (doc.exists) {
      final data = doc.data()!;
      _hotelNameCtrl.text = data['name'] ?? '';
      _hotelAdressCtrl.text = data['address'] ?? '';
      _hotelPhoneCtrl.text = data['phone'] ?? '';
      _hotelEmailCtrl.text = data['email'] ?? '';
      _hotelDescCtrl.text = data['description'] ?? '';
    }
  }

  Future<void> _loadNotifSettings() async {
    final doc =
        await _firestore.collection('settings').doc('notifications').get();
    if (doc.exists) {
      final data = doc.data()!;
      _notifEnabled = data['enabled'] ?? true;
      _notifEmail = data['email'] ?? true;
      _notifSMS = data['sms'] ?? false;
      _notifPush = data['push'] ?? true;
    }
  }

  // ── Save profile ──────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Le nom est requis');
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSuccess('Profil enregistré ✅');
    } catch (e) {
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _showError('Image trop volumineuse (max 5 Mo)');
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      final ext = picked.name.split('.').last.toLowerCase();
      final fileName =
          '${user.uid}/admin_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage.from(_bucket).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );

      final url = Supabase.instance.client.storage
          .from(_bucket)
          .getPublicUrl(fileName);

      await _firestore.collection('users').doc(user.uid).set(
          {'profileImage': url}, SetOptions(merge: true));

      setState(() {
        _profileImageUrl =
            '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      });
      _showSuccess('Photo mise à jour ✅');
    } catch (e) {
      _showError('Erreur upload : $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _sendResetEmail() async {
    final user = _auth.currentUser;
    if (user?.email == null) return;
    try {
      await _auth.sendPasswordResetEmail(email: user!.email!);
      _showSuccess('Email de réinitialisation envoyé à ${user.email}');
    } catch (e) {
      _showError('Erreur : $e');
    }
  }

  // ── Save hôtel ────────────────────────────────────────────────────────────

  Future<void> _saveHotel() async {
    setState(() => _savingHotel = true);
    try {
      await _firestore.collection('settings').doc('hotel').set({
        'name': _hotelNameCtrl.text.trim(),
        'address': _hotelAdressCtrl.text.trim(),
        'phone': _hotelPhoneCtrl.text.trim(),
        'email': _hotelEmailCtrl.text.trim(),
        'description': _hotelDescCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSuccess('Informations hôtel enregistrées ✅');
    } catch (e) {
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _savingHotel = false);
    }
  }

  // ── Save notifications ────────────────────────────────────────────────────

  Future<void> _saveNotifications() async {
    setState(() => _savingNotif = true);
    try {
      await _firestore.collection('settings').doc('notifications').set({
        'enabled': _notifEnabled,
        'email': _notifEmail,
        'sms': _notifSMS,
        'push': _notifPush,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSuccess('Paramètres notifications enregistrés ✅');
    } catch (e) {
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _savingNotif = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    return Column(
      children: [
        // En-tête
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A2A10), _primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.settings_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 12),
              const Text(
                'Paramètres',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ],
          ),
        ),

        // Onglets
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: _primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _primary,
            isScrollable: true,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.person_rounded, size: 18), text: 'Mon profil'),
              Tab(icon: Icon(Icons.hotel_rounded, size: 18), text: 'Hôtel'),
              Tab(icon: Icon(Icons.notifications_rounded, size: 18), text: 'Notifications'),
              Tab(icon: Icon(Icons.palette_rounded, size: 18), text: 'Apparence'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProfileTab(),
              _buildHotelTab(),
              _buildNotificationsTab(),
              _buildAppearanceTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Onglet Profil ─────────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    final user = _auth.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            // Avatar
            _buildCard(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!)
                            : null,
                        child: _uploadingImage
                            ? const CircularProgressIndicator(
                                color: _primary, strokeWidth: 2)
                            : _profileImageUrl == null
                                ? Text(
                                    _nameCtrl.text.isNotEmpty
                                        ? _nameCtrl.text[0].toUpperCase()
                                        : 'A',
                                    style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                        color: _primary),
                                  )
                                : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: -4,
                        child: GestureDetector(
                          onTap:
                              _uploadingImage ? null : _pickAndUploadPhoto,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(user?.email ?? '',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _buildCard(
              child: Column(
                children: [
                  _buildTextField(
                      controller: _nameCtrl,
                      label: 'Nom complet',
                      icon: Icons.person_rounded),
                  const SizedBox(height: 12),
                  _buildTextField(
                      controller: _phoneCtrl,
                      label: 'Téléphone',
                      icon: Icons.phone_rounded,
                      keyboard: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildSaveButton('Enregistrer le profil',
                      _savingProfile, _saveProfile),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sécurité',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _dark)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _sendResetEmail,
                    icon: const Icon(Icons.lock_reset_rounded,
                        size: 18, color: _primary),
                    label: const Text('Réinitialiser le mot de passe',
                        style: TextStyle(color: _primary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Onglet Hôtel ─────────────────────────────────────────────────────────

  Widget _buildHotelTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Informations de l\'hôtel',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _dark)),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _hotelNameCtrl,
                  label: 'Nom de l\'hôtel',
                  icon: Icons.hotel_rounded),
              const SizedBox(height: 12),
              _buildTextField(
                  controller: _hotelAdressCtrl,
                  label: 'Adresse',
                  icon: Icons.location_on_rounded),
              const SizedBox(height: 12),
              _buildTextField(
                  controller: _hotelPhoneCtrl,
                  label: 'Téléphone',
                  icon: Icons.phone_rounded,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField(
                  controller: _hotelEmailCtrl,
                  label: 'Email',
                  icon: Icons.email_rounded,
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hotelDescCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.description_rounded,
                        size: 18, color: _primary),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFAF5F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              _buildSaveButton(
                  'Enregistrer les infos hôtel', _savingHotel, _saveHotel),
            ],
          ),
        ),
      ),
    );
  }

  // ── Onglet Notifications ──────────────────────────────────────────────────

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _buildCard(
          child: Column(
            children: [
              _buildSwitch(
                'Notifications activées',
                'Activer ou désactiver toutes les notifications',
                _notifEnabled,
                (v) => setState(() => _notifEnabled = v),
              ),
              const Divider(height: 20),
              _buildSwitch(
                'Notifications email',
                'Recevoir des alertes par email',
                _notifEnabled && _notifEmail,
                _notifEnabled
                    ? (v) => setState(() => _notifEmail = v)
                    : null,
              ),
              const Divider(height: 20),
              _buildSwitch(
                'Notifications SMS',
                'Recevoir des alertes par SMS',
                _notifEnabled && _notifSMS,
                _notifEnabled
                    ? (v) => setState(() => _notifSMS = v)
                    : null,
              ),
              const Divider(height: 20),
              _buildSwitch(
                'Notifications push',
                'Recevoir des alertes en temps réel',
                _notifEnabled && _notifPush,
                _notifEnabled
                    ? (v) => setState(() => _notifPush = v)
                    : null,
              ),
              const SizedBox(height: 16),
              _buildSaveButton('Enregistrer les notifications',
                  _savingNotif, _saveNotifications),
            ],
          ),
        ),
      ),
    );
  }

  // ── Onglet Apparence ──────────────────────────────────────────────────────

  Widget _buildAppearanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Langue de l\'interface',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _dark)),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5F0),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _language,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'fr', child: Text('🇫🇷 Français')),
                          DropdownMenuItem(
                              value: 'en', child: Text('🇬🇧 English')),
                        ],
                        onChanged: (v) =>
                            setState(() => _language = v!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('À propos',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _dark)),
                  const SizedBox(height: 12),
                  _buildInfoItem('Application', 'FLOSTAY Admin'),
                  _buildInfoItem('Version', '2.0.0'),
                  _buildInfoItem('Environnement', 'Production'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets helper ────────────────────────────────────────────────────────

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _primary),
        filled: true,
        fillColor: const Color(0xFFFAF5F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildSwitch(String title, String subtitle, bool value,
      ValueChanged<bool>? onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _primary,
        ),
      ],
    );
  }

  Widget _buildSaveButton(
      String label, bool saving, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: saving ? null : onPressed,
        icon: saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded, size: 18),
        label: Text(saving ? 'Enregistrement...' : label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}