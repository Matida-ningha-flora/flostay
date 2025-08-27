import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfileData();
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
          });
        }
      } catch (e) {
        print("Erreur de chargement: $e");
        _showErrorSnackBar("Erreur de chargement des données");
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
        File file = File(pickedFile.path);
        
        // Vérification de la taille du fichier
        if (await file.length() > 5 * 1024 * 1024) { // 5MB max
          _showErrorSnackBar("L'image est trop grande (max 5MB)");
          setState(() => isUploadingImage = false);
          return;
        }
        
        // Upload vers Supabase Storage
        final String filePath = '${user!.uid}/profile.jpg';
        
        await Supabase.instance.client.storage
            .from('profile_images')
            .upload(filePath, file, fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ));

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
        }, SetOptions(merge: true));

        setState(() => profileImageUrl = imageUrl);
        
        _showSuccessSnackBar("Photo de profil mise à jour");
      } catch (e) {
        print("Erreur d'upload: $e");
        _showErrorSnackBar("Erreur lors de la mise à jour de la photo: ${e.toString()}");
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

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: userName);
    final phoneController = TextEditingController(text: userPhone);

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
                controller: nameController,
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
                controller: phoneController,
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
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Le nom est requis"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              setState(() => isSavingProfile = true);
              
              try {
                await FirebaseFirestore.instance
                    .collection("users")
                    .doc(user!.uid)
                    .set({
                  "name": nameController.text,
                  "phone": phoneController.text,
                }, SetOptions(merge: true));

                setState(() {
                  userName = nameController.text;
                  userPhone = phoneController.text;
                });
                
                _showSuccessSnackBar("Profil mis à jour avec succès!");
              } catch (e) {
                print("Erreur de sauvegarde: $e");
                _showErrorSnackBar("Erreur lors de la mise à jour du profil");
              } finally {
                setState(() => isSavingProfile = false);
              }
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

  // Méthode pour gérer l'erreur d'index Firestore
  Widget _buildErrorIndexMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Erreur de configuration",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          const Text(
            "Une configuration est nécessaire dans Firebase pour afficher vos réservations.",
            style: TextStyle(color: Colors.orange),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Ouvrir le lien pour créer l'index
              // _loadProfileData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text("Créer l'index"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text("Mon Profil"),
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
                        label: Text(isSavingProfile ? "Enregistrement..." : "Modifier mon profil"),
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

                    // Section réservations
                    const Text(
                      "Mes Réservations",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A2A10),
                      ),
                    ),
                    const SizedBox(height: 15),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("reservations")
                          .where("userId", isEqualTo: user!.uid)
                          .orderBy("date", descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF9B4610),
                            ),
                          );
                        }
                        
                        if (snapshot.hasError) {
                          // Vérifier si c'est une erreur d'index
                          if (snapshot.error.toString().contains("index")) {
                            return _buildErrorIndexMessage();
                          }
                          
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, size: 50, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(
                                  "Erreur de chargement",
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  snapshot.error.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8E9DD),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.hotel, size: 50, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                const Text(
                                  "Aucune réservation trouvée",
                                  style: TextStyle(fontSize: 16),
                                ),
                                const Text(
                                  "Vos futures réservations apparaîtront ici",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final date = data['date'] is Timestamp
                                ? (data['date'] as Timestamp).toDate()
                                : DateTime.now();
                            final dateStr = DateFormat('dd/MM/yyyy').format(date);
                            final price = data['price'] ?? "0";

                            return Card(
                              margin: const EdgeInsets.only(bottom: 15),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9B4610).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.hotel,
                                      color: Color(0xFF9B4610)),
                                ),
                                title: Text(
                                  data['roomType']?.toString() ?? "Chambre inconnue",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),
                                    Text("Date: $dateStr"),
                                    Text(
                                      "$price FCFA",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right,
                                    color: Color(0xFF9B4610)),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}