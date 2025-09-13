import 'dart:io';
import 'package:flostay/pages/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'app_localizations.dart';
import 'language_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  String? profileImageUrl;
  String userName = "";
  String userPhone = "";
  bool isLoading = false;
  bool isSavingProfile = false;
  bool isUploadingImage = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ne pas charger les données qui dépendent du contexte ici
    // Le chargement sera fait dans didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isLoading && userName.isEmpty) {
      _loadProfileData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (user != null) {
      setState(() => isLoading = true);
      try {
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user!.uid)
            .get();

        if (doc.exists) {
          setState(() {
            profileImageUrl = doc.data()?["profileImage"];
            userName = doc.data()?["name"] ?? "";
            userPhone = doc.data()?["phone"] ?? "";
            
            _nameController.text = userName;
            _phoneController.text = userPhone;
          });
        }
      } catch (e) {
        print("Erreur de chargement: $e");
        // Utilisation directe de la traduction sans dépendre du contexte
        _showErrorSnackBar("Erreur de chargement du profil");
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (pickedFile != null && user != null) {
      setState(() => isUploadingImage = true);

      try {
        // Lire le fichier en bytes
        final bytes = await pickedFile.readAsBytes();
        final fileSize = bytes.length;
        
        if (fileSize > 5 * 1024 * 1024) {
          _showErrorSnackBar("L'image est trop volumineuse (max 5MB)");
          setState(() => isUploadingImage = false);
          return;
        }
        
        final String filePath = '${user!.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        print("Tentative d'upload vers Supabase: $filePath");
        
        // Upload vers Supabase Storage en utilisant les bytes
        await Supabase.instance.client.storage
            .from('profile_images')
            .uploadBinary(
              filePath, 
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        // Récupérer l'URL publique
        final String imageUrl = Supabase.instance.client.storage
            .from('profile_images')
            .getPublicUrl(filePath);

        // Mettre à jour Firestore avec la nouvelle URL
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user!.uid)
            .set({
          "profileImage": imageUrl,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        setState(() => profileImageUrl = "$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}");
        
        _showSuccessSnackBar("Photo de profil mise à jour");
      } catch (e) {
        print("Erreur détaillée: $e");
        
        if (e.toString().contains('row-level security policy')) {
          _showErrorSnackBar("Erreur de sécurité Supabase");
          _showSupabaseSetupInstructions();
        } else if (e.toString().contains('403')) {
          _showErrorSnackBar("Accès refusé");
          _showSupabaseSetupInstructions();
        } else {
          _showErrorSnackBar("Erreur de mise à jour: ${e.toString()}");
        }
      } finally {
        setState(() => isUploadingImage = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSupabaseSetupInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Configuration Supabase requise"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Veuillez configurer correctement Supabase pour utiliser cette fonctionnalité."),
              const SizedBox(height: 15),
              const Text("1. Allez dans l'interface Supabase", style: TextStyle(fontWeight: FontWeight.bold)),
              const Text("2. Activez le stockage pour les images de profil"),
              const Text("3. Configurez les politiques RLS:"),
              const SizedBox(height: 10),
              const Text("- Sélectionnez 'Enable read access for authenticated users only'", style: TextStyle(fontSize: 12)),
              const Text("- Créez une politique d'insertion pour les utilisateurs authentifiés", style: TextStyle(fontSize: 12)),
              const Text("- Créez une politique de mise à jour pour les propriétaires des fichiers", style: TextStyle(fontSize: 12)),
              const Text("- Créez une politique de suppression pour les propriétaires des fichiers", style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Compris"),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier le profil",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Nom complet",
                  labelStyle: const TextStyle(color: Color(0xFF6D5D4F)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF9B4610)),
                  ),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF9B4610)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: "Téléphone",
                  labelStyle: const TextStyle(color: Color(0xFF6D5D4F)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF9B4610)),
                  ),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF9B4610)),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Le nom est requis"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _saveProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B4610),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Enregistrer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => isSavingProfile = true);
    
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .set({
        "name": _nameController.text,
        "phone": _phoneController.text,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        userName = _nameController.text;
        userPhone = _phoneController.text;
      });
      
      _showSuccessSnackBar("Profil mis à jour");
    } catch (e) {
      print("Erreur de sauvegarde: $e");
      _showErrorSnackBar("Erreur de mise à jour");
    } finally {
      setState(() => isSavingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    if (user == null) {
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
                const Icon(Icons.error_outline, size: 60, color: Color(0xFF9B4610)),
                const SizedBox(height: 20),
                const Text(
                  "Aucun utilisateur connecté",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, "/login");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B4610),
                  ),
                  child: const Text("Se connecter"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon profil"),
        centerTitle: true,
        backgroundColor: const Color(0xFF9B4610),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, "/login");
            },
          )
        ],
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
        child: isLoading || isUploadingImage
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B4610)),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header avec avatar
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF9B4610).withOpacity(0.5),
                                    width: 3,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: profileImageUrl != null
                                      ? NetworkImage(profileImageUrl!)
                                      : null,
                                  child: profileImageUrl == null
                                      ? const Icon(Icons.person,
                                          size: 60, color: Color(0xFF9B4610))
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: -5,
                                right: -5,
                                child: InkWell(
                                  onTap: isUploadingImage ? null : _pickAndUploadImage,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isUploadingImage 
                                          ? Colors.grey 
                                          : const Color(0xFF9B4610),
                                      shape: BoxShape.circle,
                                    ),
                                    child: isUploadingImage
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.camera_alt,
                                            size: 20, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            userName.isNotEmpty ? userName : "Nom non défini",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A2A10),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user!.email ?? "",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (userPhone.isNotEmpty)
                            Text(
                              userPhone,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Bouton modifier profil
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: isSavingProfile ? null : _editProfile,
                        icon: isSavingProfile
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF9B4610),
                                ),
                              )
                            : const Icon(Icons.edit),
                        label: Text(isSavingProfile ? "Enregistrement..." : "Modifier le profil"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF9B4610),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(color: Color(0xFF9B4610)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Section changement de langue
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Langue",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A2A10),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButton<String>(
                              value: languageProvider.currentLocale.languageCode,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'fr',
                                  child: Text("Français"),
                                ),
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Text("Anglais"),
                                ),
                              ],
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  languageProvider.setLocale(Locale(newValue));
                                  _showSuccessSnackBar("Langue changée en ${newValue == 'fr' ? 'Français' : 'Anglais'}");
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}