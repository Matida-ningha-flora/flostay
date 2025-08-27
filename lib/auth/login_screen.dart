import 'package:flostay/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_gate.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "Aucun utilisateur trouvé avec cet email.";
          break;
        case 'wrong-password':
          errorMessage = "Mot de passe incorrect.";
          break;
        case 'invalid-email':
          errorMessage = "Adresse email invalide.";
          break;
        case 'user-disabled':
          errorMessage = "Ce compte a été désactivé.";
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

  Future<void> _resetPassword() async {
    final emailController = TextEditingController();
    final theme = Theme.of(context);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Réinitialiser le mot de passe", style: theme.textTheme.titleMedium),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: "Email",
            hintText: "Entrez votre email",
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Veuillez entrer un email"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await _authService.resetPassword(emailController.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Email de réinitialisation envoyé!"),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Erreur: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Envoyer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;
    final theme = Theme.of(context);
    
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? size.width * 0.1 : size.width * 0.05,
                vertical: size.height * 0.02,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  minHeight: size.height - MediaQuery.of(context).padding.vertical,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Title Section
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9B4610),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Icon(
                            Icons.hotel,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "FLOSTAY",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4A2A10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Connectez-vous à votre compte",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Form Section
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
                                      _obscurePassword 
                                        ? Icons.visibility 
                                        : Icons.visibility_off,
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
                                    return "Veuillez entrer votre mot de passe";
                                  }
                                  if (val.length < 6) {
                                    return "Le mot de passe doit contenir au moins 6 caractères";
                                  }
                                  return null;
                                },
                              ),
                              
                              const SizedBox(height: 24),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _login,
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
                                      : const Text("Se connecter"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Footer Section
                    Column(
                      children: [
                        TextButton(
                          onPressed: _resetPassword,
                          child: Text(
                            "Mot de passe oublié ?",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF9B4610),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Pas encore inscrit ? ",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                "Créer un compte",
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