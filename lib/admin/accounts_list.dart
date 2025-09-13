import 'package:flostay/pages/create_staff_page.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountsList extends StatefulWidget {
  const AccountsList({super.key});

  @override
  State<AccountsList> createState() => _AccountsListState();
}

class _AccountsListState extends State<AccountsList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _filterRole = 'tous';
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _getCurrentUserRole();
  }

  void _getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _currentUserRole = doc.get('role');
        });
      }
    }
  }

  Future<void> _deleteAccount(String userId, String email) async {
    final currentUser = _auth.currentUser;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content: Text(
            "Êtes-vous sûr de vouloir supprimer le compte de $email ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  // Vérifier si l'utilisateur supprime son propre compte
                  final isDeletingOwnAccount =
                      currentUser != null && currentUser.uid == userId;

                  await _firestore.collection('users').doc(userId).delete();

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Compte $email supprimé avec succès"),
                    ),
                  );

                  // Si l'utilisateur supprime son propre compte, le déconnecter
                  if (isDeletingOwnAccount) {
                    await _auth.signOut();
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erreur lors de la suppression: $e"),
                    ),
                  );
                }
              },
              child: const Text(
                "Supprimer",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Query usersQuery = _firestore.collection('users');
    if (_filterRole != 'tous') {
      usersQuery = usersQuery.where('role', isEqualTo: _filterRole);
    }

    return Scaffold(
      floatingActionButton: _currentUserRole == 'admin'
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateStaffPage(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF9B4610),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      "Filtrer par rôle:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filterRole,
                        onChanged: (String? newValue) {
                          setState(() {
                            _filterRole = newValue!;
                          });
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'tous',
                            child: Text("Tous les utilisateurs"),
                          ),
                          DropdownMenuItem(
                            value: 'client',
                            child: Text("Clients"),
                          ),
                          DropdownMenuItem(
                            value: 'receptionniste',
                            child: Text("Réceptionnistes"),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text("Administrateurs"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: usersQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                final users = snapshot.data!.docs;

                if (users.isEmpty) {
                  return const Center(child: Text("Aucun utilisateur trouvé"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    final name = data['name'] ?? 'Sans nom';
                    final email = data['email'] ?? 'Sans email';
                    final role = data['role'] ?? 'client';

                    Color roleColor;
                    switch (role) {
                      case 'admin':
                        roleColor = const Color(0xFF9B4610);
                        break;
                      case 'receptionniste':
                        roleColor = const Color(0xFF9B4610);
                        break;
                      default:
                        roleColor = const Color(0xFF9B4610);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: Colors.white,
                      elevation: 4,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF9B4610,
                          ).withOpacity(0.2),
                          foregroundColor: const Color(0xFF9B4610),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.black),
                        ),
                        subtitle: Column(
                          children: [
                            Text(
                              email,
                              style: const TextStyle(color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: _currentUserRole == 'admin'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _deleteAccount(userId, email),
                                    tooltip: "Supprimer",
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}