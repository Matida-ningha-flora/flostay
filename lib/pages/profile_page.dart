// ============================================================
// profile_page.dart (VERSION AMÉLIORÉE)
//
// Profil client avec :
// - Photo de profil (upload vers Supabase bucket 'profile-images')
// - Édition inline nom + téléphone
// - Affichage stats : réservations, commandes
// - Changement de langue
// - Déconnexion
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);
  static const _bucket = 'profile-images';

  final user = FirebaseAuth.instance.currentUser;

  // Données profil
  String _name = '';
  String _phone = '';
  String? _profileImageUrl;

  // États
  bool _isLoading = true;
  bool _isUploadingImage = false;
  bool _isSaving = false;
  bool _isEditing = false;

  // Stats
  int _reservationsCount = 0;
  int _commandesCount = 0;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Charger le profil ─────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _name = data['name'] ?? '';
          _phone = data['phone'] ?? '';
          _profileImageUrl = data['profileImage'];
          _nameCtrl.text = _name;
          _phoneCtrl.text = _phone;
        });
      }
    } catch (e) {
      _showError('Erreur de chargement du profil');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Charger les stats ─────────────────────────────────────────────────────

  Future<void> _loadStats() async {
    if (user == null) return;
    try {
      final reservations = await FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: user!.uid)
          .get();

      final commandes = await FirebaseFirestore.instance
          .collection('commandes')
          .where('userId', isEqualTo: user!.uid)
          .get();

      if (mounted) {
        setState(() {
          _reservationsCount = reservations.size;
          _commandesCount = commandes.size;
        });
      }
    } catch (_) {}
  }

  // ── Sélectionner et uploader une image ───────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      // Vérifier taille (max 5MB)
      if (bytes.length > 5 * 1024 * 1024) {
        _showError('Image trop volumineuse (max 5 Mo)');
        return;
      }

      setState(() => _isUploadingImage = true);

      final ext = picked.name.split('.').last.toLowerCase();
      final fileName = '${user!.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload vers Supabase
      await Supabase.instance.client.storage
          .from(_bucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$ext',
              upsert: true,
            ),
          );

      // URL publique
      final imageUrl = Supabase.instance.client.storage
          .from(_bucket)
          .getPublicUrl(fileName);

      // Sauvegarder dans Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({'profileImage': imageUrl}, SetOptions(merge: true));

      setState(() {
        _profileImageUrl = '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      });

      _showSuccess('Photo de profil mise à jour ✅');
    } catch (e) {
      _showError('Erreur upload : $e');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // ── Sauvegarder le profil ────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (user == null) return;
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Le nom est requis');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _name = _nameCtrl.text.trim();
        _phone = _phoneCtrl.text.trim();
        _isEditing = false;
      });

      _showSuccess('Profil mis à jour ✅');
    } catch (e) {
      _showError('Erreur de sauvegarde');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Aucun utilisateur connecté')),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bgLight,
        body: Center(
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _nameCtrl.text = _name;
                  _phoneCtrl.text = _phone;
                });
              },
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white70)),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header gradient avec avatar ───────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A2A10), _primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // Avatar + bouton caméra
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: _isUploadingImage
                              ? const CircularProgressIndicator(
                                  color: _primary, strokeWidth: 2)
                              : _profileImageUrl == null
                                  ? Text(
                                      _name.isNotEmpty
                                          ? _name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w700,
                                        color: _primary,
                                      ),
                                    )
                                  : null,
                        ),
                      ),

                      // Bouton caméra
                      Positioned(
                        bottom: 0,
                        right: -4,
                        child: GestureDetector(
                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _isUploadingImage
                                  ? Colors.grey
                                  : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: _isUploadingImage
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.camera_alt_rounded,
                                    size: 18, color: _primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nom et email
                  Text(
                    _name.isNotEmpty ? _name : 'Nom non défini',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user!.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                  if (_phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _phone,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStat('Réservations', _reservationsCount,
                          Icons.hotel_rounded),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      _buildStat('Commandes', _commandesCount,
                          Icons.room_service_rounded),
                    ],
                  ),
                ],
              ),
            ),

            // ── Corps ─────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(isWeb ? 24 : 16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isWeb ? 600 : double.infinity),
                child: Column(
                  children: [
                    // ── Informations personnelles ─────────────────────────
                    _buildSection(
                      title: 'Informations personnelles',
                      icon: Icons.person_rounded,
                      trailing: _isEditing
                          ? _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _primary))
                              : TextButton(
                                  onPressed: _saveProfile,
                                  child: const Text('Enregistrer',
                                      style: TextStyle(
                                          color: _primary,
                                          fontWeight: FontWeight.w700)),
                                )
                          : TextButton.icon(
                              onPressed: () =>
                                  setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit_rounded,
                                  size: 16, color: _primary),
                              label: const Text('Modifier',
                                  style: TextStyle(color: _primary)),
                            ),
                      child: Column(
                        children: [
                          _buildField(
                            label: 'Nom complet',
                            controller: _nameCtrl,
                            icon: Icons.person_outline_rounded,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            label: 'Téléphone',
                            controller: _phoneCtrl,
                            icon: Icons.phone_rounded,
                            enabled: _isEditing,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            label: 'Email',
                            value: user!.email ?? '',
                            icon: Icons.email_rounded,
                            enabled: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Sécurité ──────────────────────────────────────────
                    _buildSection(
                      title: 'Sécurité',
                      icon: Icons.security_rounded,
                      child: Column(
                        children: [
                          _buildActionTile(
                            icon: Icons.lock_rounded,
                            iconColor: Colors.blue,
                            label: 'Changer le mot de passe',
                            onTap: () => _showChangePasswordDialog(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Déconnexion ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('Déconnexion'),
                              content: const Text(
                                  'Voulez-vous vous déconnecter ?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white),
                                  child: const Text('Déconnexion'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await FirebaseAuth.instance.signOut();
                          }
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Se déconnecter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          elevation: 0,
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets helper ────────────────────────────────────────────────────────

  Widget _buildStat(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.85), size: 20),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    TextEditingController? controller,
    String? value,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    if (controller == null && value != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[500]),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(value,
                    style: const TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ),
          ],
        ),
      );
    }

    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _primary),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF5F5F5),
        labelStyle: const TextStyle(fontSize: 13),
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final emailCtrl =
        TextEditingController(text: user!.email);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Réinitialiser le mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Un email de réinitialisation sera envoyé à votre adresse email.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(user!.email ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: _primary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: user!.email!);
                _showSuccess('Email de réinitialisation envoyé ✅');
              } catch (e) {
                _showError('Erreur : $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
}