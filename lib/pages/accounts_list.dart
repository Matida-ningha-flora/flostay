// ============================================================
// accounts_list.dart — VERSION AMÉLIORÉE
//
// ✅ Bouton "Voir profil" sur chaque utilisateur
// ✅ Ouvre UserProfileAdminPage avec analytics complets
// ✅ Filtre par rôle
// ✅ Bouton ajouter staff
// ✅ Bouton supprimer
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flostay/pages/create_staff_page.dart';
import 'package:flostay/pages/user_profile_admin_page.dart';

class AccountsList extends StatefulWidget {
  const AccountsList({super.key});

  @override
  State<AccountsList> createState() => _AccountsListState();
}

class _AccountsListState extends State<AccountsList> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  String _filterRole = 'Tous les utilisateurs';

  final _roles = [
    'Tous les utilisateurs',
    'client',
    'receptionniste',
    'cuisine',
    'admin',
  ];

  // Couleurs badges par rôle
  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.purple;
      case 'receptionniste': return Colors.blue;
      case 'cuisine': return Colors.orange;
      default: return _primary;
    }
  }

  Future<void> _deleteUser(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Voulez-vous vraiment supprimer "$name" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name supprimé'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _openUserProfile(
      BuildContext context, String uid, String name, String email, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileAdminPage(
          userId: uid,
          userName: name,
          userEmail: email,
          userRole: role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filtre rôle ────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterRole,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: _primary),
              items: _roles.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Row(
                    children: [
                      Text(
                        'Filtrer par rôle: ',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500]),
                      ),
                      Text(
                        r,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _primary),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _filterRole = v!),
            ),
          ),
        ),

        // ── Liste utilisateurs ─────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _primary));
              }

              var docs = snap.data?.docs ?? [];

              // Filtre rôle
              if (_filterRole != 'Tous les utilisateurs') {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final role =
                      (data['role'] ?? '').toString().toLowerCase();
                  return role == _filterRole.toLowerCase();
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun utilisateur',
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final uid = doc.id;
                  final name = data['name'] ??
                      data['displayName'] ??
                      data['email']?.toString().split('@').first ??
                      'Utilisateur';
                  final email = data['email'] ?? '';
                  final role = data['role'] ?? 'client';
                  final profileImage = data['profileImage'] as String?;
                  final initial =
                      name.isNotEmpty ? name[0].toUpperCase() : '?';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openUserProfile(context, uid, name, email, role),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Ligne header : avatar + nom + actions ──────
                            Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: _primary.withOpacity(0.12),
                                  backgroundImage: profileImage != null
                                      ? NetworkImage(profileImage)
                                      : null,
                                  child: profileImage == null
                                      ? Text(initial,
                                          style: const TextStyle(
                                              color: _primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18))
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Nom + email + badge rôle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: _dark)),
                                      const SizedBox(height: 2),
                                      Text(email,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500])),
                                      const SizedBox(height: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _roleColor(role).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(role.toUpperCase(),
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _roleColor(role))),
                                      ),
                                    ],
                                  ),
                                ),
                                // Bouton supprimer
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded,
                                      color: Colors.red, size: 20),
                                  onPressed: () => _deleteUser(uid, name),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            // ── Bouton Voir profil complet ─────────────────
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _openUserProfile(context, uid, name, email, role),
                                icon: const Icon(Icons.person_search_rounded, size: 16),
                                label: const Text('Voir le profil complet',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}