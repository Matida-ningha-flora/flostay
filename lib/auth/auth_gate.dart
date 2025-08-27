import 'package:flostay/pages/admin_page.dart';
import 'package:flostay/pages/client_client.dart';
import 'package:flostay/pages/reception_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<String?> _getUserRole(String uid) async {
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();
      if (doc.exists) {
        return doc["role"];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWeb = constraints.maxWidth > 600;
        
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo.png', // Remplacez par le chemin de votre logo
                        width: isWeb ? 150 : 100,
                        height: isWeb ? 150 : 100,
                      ),
                      SizedBox(height: isWeb ? 40 : 20),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF9B4610),
                        ),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: isWeb ? 20 : 15),
                      Text(
                        "Chargement...",
                        style: TextStyle(
                          fontSize: isWeb ? 18 : 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const LoginScreen();
            }

            String uid = snapshot.data!.uid;

            return FutureBuilder<String?>(
              future: _getUserRole(uid),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF9B4610),
                            ),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: isWeb ? 20 : 15),
                          Text(
                            "Vérification des permissions...",
                            style: TextStyle(
                              fontSize: isWeb ? 18 : 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!roleSnapshot.hasData || roleSnapshot.data == null) {
                  // Si l'utilisateur n'a pas de rôle, le déconnecter
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FirebaseAuth.instance.signOut();
                    
                    // Afficher un message d'erreur
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Erreur: Aucun rôle trouvé pour cet utilisateur",
                          style: TextStyle(fontSize: isWeb ? 16 : 14),
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  });
                  return const LoginScreen();
                }

                switch (roleSnapshot.data) {
                  case "client":
                    return const ClientClient();
                  case "receptionist":
                    return const ReceptionPage();
                  case "admin":
                    return const AdminPage();
                  default:
                    // Rôle inconnu, déconnecter l'utilisateur
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      FirebaseAuth.instance.signOut();
                      
                      // Afficher un message d'erreur
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Erreur: Rôle inconnu (${roleSnapshot.data})",
                            style: TextStyle(fontSize: isWeb ? 16 : 14),
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    });
                    return const LoginScreen();
                }
              },
            );
          },
        );
      },
    );
  }
}