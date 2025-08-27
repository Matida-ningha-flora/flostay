import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'auth/login_screen.dart';
import 'pages/client_client.dart';
import 'pages/reception_page.dart';
import 'pages/admin_page.dart';
import 'firebase_options.dart'; // généré par flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialisation de Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialisation de Supabase avec vos informations
    await Supabase.initialize(
      url: 'https://epdzwqysuzvjyadmcuwk.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwZHp3cXlzdXp2anlhZG1jdXdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMxMzQ2NDAsImV4cCI6MjA2ODcxMDY0MH0.b0ymXP4w2sjwlhoqge2JGylp_JegVhdgjxjPFwo7r7Q',
    );
    
    debugPrint("✅ Firebase et Supabase initialisés avec succès");
  } catch (e) {
    debugPrint("❌ Erreur d'initialisation Firebase/Supabase : $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLOSTAY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF9B4610),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B4610),
          primary: const Color(0xFF9B4610),
          secondary: const Color(0xFF4A2A10),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF9B4610),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          elevation: 4,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9B4610),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            elevation: 5,
            shadowColor: Colors.orange[300],
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9B4610), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87, fontSize: 16),
          bodyLarge: TextStyle(color: Colors.black87, fontSize: 18),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF9B4610),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWeb = constraints.maxWidth > 600;
        
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Chargement initial
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen(isWeb);
            }

            // Vérifier si l'utilisateur a été supprimé
            if (snapshot.hasData && snapshot.data != null) {
              final userId = snapshot.data!.uid;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, snapshotRole) {
                  if (snapshotRole.connectionState == ConnectionState.waiting) {
                    return _buildLoadingScreen(isWeb);
                  }

                  // Si l'utilisateur n'existe plus dans Firestore, le déconnecter
                  if (snapshotRole.hasError || !snapshotRole.hasData || !snapshotRole.data!.exists) {
                    // Déconnecter l'utilisateur car son compte a été supprimé
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      FirebaseAuth.instance.signOut();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Votre compte a été supprimé",
                            style: TextStyle(fontSize: isWeb ? 16 : 14),
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    });
                    
                    return const LoginScreen();
                  }

                  final role = snapshotRole.data!.get('role');

                  switch (role) {
                    case 'client':
                      return const ClientClient();
                    case 'receptionniste':
                      return const ReceptionPage();
                    case 'admin':
                      return const AdminPage();
                    default:
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        FirebaseAuth.instance.signOut();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Rôle inconnu. Contactez l'administrateur.",
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
            }

            // Utilisateur pas connecté → page de login
            return const LoginScreen();
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen(bool isWeb) {
    return Scaffold(
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hotel,
                size: isWeb ? 100 : 80,
                color: const Color(0xFF9B4610),
              ),
              SizedBox(height: isWeb ? 30 : 20),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF9B4610)),
                strokeWidth: 4,
              ),
              SizedBox(height: isWeb ? 20 : 15),
              Text(
                "Chargement de FLOSTAY...",
                style: TextStyle(
                  fontSize: isWeb ? 18 : 16,
                  color: const Color(0xFF9B4610),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}