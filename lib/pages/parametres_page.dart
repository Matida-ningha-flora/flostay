import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({Key? key}) : super(key: key);

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  // Paramètres de notification
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _pushNotifications = true;
  
  // Paramètres d'application
  bool _darkMode = false;
  bool _autoSync = true;
  String _language = 'fr';
  int _syncInterval = 15;
  
  // Paramètres de compte
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isEditingProfile = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  void _loadSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('notifications').get();
      if (doc.exists) {
        setState(() {
          _notificationsEnabled = doc.get('enabled') ?? true;
          _emailNotifications = doc.get('email') ?? true;
          _smsNotifications = doc.get('sms') ?? false;
          _pushNotifications = doc.get('push') ?? true;
        });
      }

      final appSettings = await _firestore.collection('settings').doc('app_settings').get();
      if (appSettings.exists) {
        setState(() {
          _darkMode = appSettings.get('darkMode') ?? false;
          _autoSync = appSettings.get('autoSync') ?? true;
          _language = appSettings.get('language') ?? 'fr';
          _syncInterval = appSettings.get('syncInterval') ?? 15;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des paramètres: $e');
    }
  }

  void _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _nameController.text = userDoc.get('name') ?? '';
          _emailController.text = userDoc.get('email') ?? user.email ?? '';
          _phoneController.text = userDoc.get('phone') ?? '';
        });
      } else {
        setState(() {
          _emailController.text = user.email ?? '';
        });
      }
    }
  }

  void _saveNotificationSettings() async {
    try {
      await _firestore.collection('settings').doc('notifications').set({
        'enabled': _notificationsEnabled,
        'email': _emailNotifications,
        'sms': _smsNotifications,
        'push': _pushNotifications,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres de notification sauvegardés')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _saveAppSettings() async {
    try {
      await _firestore.collection('settings').doc('app_settings').set({
        'darkMode': _darkMode,
        'autoSync': _autoSync,
        'language': _language,
        'syncInterval': _syncInterval,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres de l\'application sauvegardés')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _reauthenticateUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Demander à l'utilisateur de saisir à nouveau son mot de passe
    final password = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController passwordController = TextEditingController();
        return AlertDialog(
          title: const Text('Ré-authentification requise'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mot de passe actuel',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, passwordController.text),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (password == null || password.isEmpty) {
      throw Exception('Mot de passe requis pour la ré-authentification');
    }

    // Recréer les credentials pour la ré-authentification
    final AuthCredential credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    // Ré-authentifier l'utilisateur
    await user.reauthenticateWithCredential(credential);
  }

  void _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès')),
        );
        
        setState(() {
          _isEditingProfile = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du profil: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    const url = 'https://votre-domaine.com/privacy-policy';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la politique de confidentialité')),
      );
    }
  }

  Future<void> _launchTermsOfService() async {
    const url = 'https://votre-domaine.com/terms-of-service';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir les conditions d\'utilisation')),
      );
    }
  }

  Future<void> _showResetConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Réinitialiser les paramètres'),
          content: const Text('Êtes-vous sûr de vouloir réinitialiser tous les paramètres aux valeurs par défaut?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                _resetSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Réinitialiser', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _resetSettings() {
    setState(() {
      _notificationsEnabled = true;
      _emailNotifications = true;
      _smsNotifications = false;
      _pushNotifications = true;
      _darkMode = false;
      _autoSync = true;
      _language = 'fr';
      _syncInterval = 15;
    });

    _saveNotificationSettings();
    _saveAppSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paramètres réinitialisés aux valeurs par défaut')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        actions: [
          if (_currentPageIndex == 2 && _isEditingProfile)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveProfile,
            ),
          if (_currentPageIndex != 2)
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: _showResetConfirmation,
              tooltip: 'Réinitialiser les paramètres',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabButton(0, Icons.notifications, 'Notifications'),
                _buildTabButton(1, Icons.settings, 'Application'),
                _buildTabButton(2, Icons.person, 'Profil'),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              children: [
                _buildNotificationsTab(),
                _buildAppSettingsTab(),
                _buildProfileTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _currentPageIndex == index;
    return Expanded(
      child: TextButton.icon(
        icon: Icon(icon, color: isSelected ? const Color(0xFF9B4610) : Colors.grey),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF9B4610) : Colors.grey,
            fontSize: 12,
          ),
        ),
        onPressed: () {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paramètres de notification',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF9B4610),
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Notifications activées'),
                  subtitle: const Text('Activer/désactiver toutes les notifications'),
                  value: _notificationsEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    _saveNotificationSettings();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notifications par email'),
                  subtitle: const Text('Recevoir des notifications par email'),
                  value: _notificationsEnabled && _emailNotifications,
                  onChanged: !_notificationsEnabled
                      ? null
                      : (bool value) {
                          setState(() {
                            _emailNotifications = value;
                          });
                          _saveNotificationSettings();
                        },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notifications par SMS'),
                  subtitle: const Text('Recevoir des notifications par SMS'),
                  value: _notificationsEnabled && _smsNotifications,
                  onChanged: !_notificationsEnabled
                      ? null
                      : (bool value) {
                          setState(() {
                            _smsNotifications = value;
                          });
                          _saveNotificationSettings();
                        },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notifications push'),
                  subtitle: const Text('Recevoir des notifications push'),
                  value: _notificationsEnabled && _pushNotifications,
                  onChanged: !_notificationsEnabled
                      ? null
                      : (bool value) {
                          setState(() {
                            _pushNotifications = value;
                          });
                          _saveNotificationSettings();
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveNotificationSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B4610),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Sauvegarder les paramètres de notification'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paramètres de l\'application',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF9B4610),
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Mode sombre'),
                  subtitle: const Text('Activer le mode sombre'),
                  value: _darkMode,
                  onChanged: (bool value) {
                    setState(() {
                      _darkMode = value;
                    });
                    _saveAppSettings();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Synchronisation automatique'),
                  subtitle: const Text('Synchroniser les données automatiquement'),
                  value: _autoSync,
                  onChanged: (bool value) {
                    setState(() {
                      _autoSync = value;
                    });
                    _saveAppSettings();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Langue'),
                  subtitle: const Text('Choisir la langue de l\'application'),
                  trailing: DropdownButton<String>(
                    value: _language,
                    onChanged: (String? newValue) {
                      setState(() {
                        _language = newValue!;
                      });
                      _saveAppSettings();
                    },
                    items: const [
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'es', child: Text('Español')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Intervalle de synchronisation'),
                  subtitle: Text('Toutes les $_syncInterval minutes'),
                  trailing: DropdownButton<int>(
                    value: _syncInterval,
                    onChanged: (int? newValue) {
                      setState(() {
                        _syncInterval = newValue!;
                      });
                      _saveAppSettings();
                    },
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 min')),
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 60, child: Text('1 heure')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Politique de confidentialité'),
                  onTap: _launchPrivacyPolicy,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Conditions d\'utilisation'),
                  onTap: _launchTermsOfService,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('À propos de l\'application'),
                  subtitle: const Text('Version 1.0.0'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'FLOSTAY Admin',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.hotel, size: 40, color: Color(0xFF9B4610)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveAppSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B4610),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Sauvegarder les paramètres de l\'application'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profil utilisateur',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF9B4610),
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF9B4610),
                    child: Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(fontSize: 32, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    enabled: _isEditingProfile,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    enabled: _isEditingProfile,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    enabled: _isEditingProfile,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  if (!_isEditingProfile)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isEditingProfile = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B4610),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Modifier le profil'),
                      ),
                    ),
                  if (_isEditingProfile)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isEditingProfile = false;
                                _loadUserProfile(); // Recharger les données originales
                              });
                            },
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B4610),
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white),
                                  )
                                : const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock, color: Colors.blue),
                  title: const Text('Changer le mot de passe'),
                  onTap: () {
                    // Implémenter la logique de changement de mot de passe
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fonctionnalité à implémenter')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.orange),
                  title: const Text('Historique des connexions'),
                  onTap: () {
                    // Implémenter la visualisation de l'historique des connexions
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fonctionnalité à implémenter')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}