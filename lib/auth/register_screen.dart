import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Les mots de passe ne correspondent pas"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "uid": uid,
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "role": "client",
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Compte créé avec succès ✅"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Correction importante: Utiliser Navigator.pushAndRemoveUntil pour vider la pile de navigation
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false, // Cette condition supprime toutes les routes précédentes
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = "Un compte avec cet email existe déjà.";
          break;
        case 'invalid-email':
          errorMessage = "Adresse email invalide.";
          break;
        case 'operation-not-allowed':
          errorMessage = "L'inscription n'est pas autorisée.";
          break;
        case 'weak-password':
          errorMessage = "Le mot de passe est trop faible.";
          break;
        default:
          errorMessage = "Une erreur s'est produite. Veuillez réessayer.";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur inattendue: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inscription"),
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? size.width * 0.1 : size.width * 0.05,
                vertical: size.height * 0.02,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: size.height * 0.02),
                    Text(
                      "Créer un compte client",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4A2A10),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.01),
                    Text(
                      "Remplissez les informations pour créer votre compte client",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.04),
                    
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: "Nom complet",
                                  prefixIcon: const Icon(Icons.person, color: Color(0xFF9B4610)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF9B4610)),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return "Veuillez entrer votre nom";
                                  }
                                  if (val.length < 2) {
                                    return "Le nom doit contenir au moins 2 caractères";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: "Email",
                                  prefixIcon: const Icon(Icons.email, color: Color(0xFF9B4610)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF9B4610)),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return "Veuillez entrer votre email";
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                                    return "Veuillez entrer un email valide";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: "Mot de passe",
                                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF9B4610)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF9B4610)),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                      color: const Color(0xFF9B4610),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return "Veuillez entrer un mot de passe";
                                  }
                                  if (val.length < 6) {
                                    return "Le mot de passe doit contenir au moins 6 caractères";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration: InputDecoration(
                                  labelText: "Confirmer le mot de passe",
                                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9B4610)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF9B4610)),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                      color: const Color(0xFF9B4610),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword = !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscureConfirmPassword,
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return "Veuillez confirmer votre mot de passe";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9B4610),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text("S'inscrire"),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Déjà inscrit ? ",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                                      );
                                    },
                                    child: Text(
                                      "Se connecter",
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF9B4610),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}