// app_localizations.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // Liste des langues supportées
  static const List<Locale> supportedLocales = [
    Locale('fr', ''),
    Locale('en', ''),
  ];

  // Traductions en français
  static Map<String, Map<String, String>> _localizedValues = {
    'fr': {
      'myProfile': 'Mon Profil',
      'editProfile': 'Modifier mon profil',
      'fullName': 'Nom complet',
      'phone': 'Téléphone',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'nameRequired': 'Le nom est requis',
      'profileUpdated': 'Profil mis à jour avec succès!',
      'updateError': 'Erreur lors de la mise à jour du profil',
      'profilePhotoUpdated': 'Photo de profil mise à jour avec succès',
      'updatePhotoError': 'Erreur lors de la mise à jour de la photo',
      'imageTooLarge': 'L\'image est trop grande. Maximum: 5MB',
      'securityError': 'Erreur de sécurité. Vérifiez les politiques Supabase.',
      'accessDenied': 'Accès refusé. Vérifiez les politiques Supabase.',
      'supabaseSetupRequired': 'Configuration Supabase requise',
      'supabaseSetupInstructions': 'Pour que les photos de profil fonctionnent, vous devez configurer Supabase :',
      'supabaseStep1': 'Allez dans Storage → Buckets → profile_images',
      'supabaseStep2': 'Activez l\'option \'Public\' pour le bucket',
      'supabaseStep3': 'Configurez les politiques de sécurité',
      'supabasePolicySelect': '- Politique SELECT: bucket_id = \'profile_images\' (pour public)',
      'supabasePolicyInsert': '- Politique INSERT: bucket_id = \'profile_images\' AND (storage.foldername(name))[1] = auth.uid()::text (pour authenticated)',
      'supabasePolicyUpdate': '- Politique UPDATE: Même condition que INSERT',
      'supabasePolicyDelete': '- Politique DELETE: Même condition que INSERT',
      'understand': 'J\'ai compris',
      'noUser': 'Aucun utilisateur connecté',
      'login': 'Se connecter',
      'noName': 'Nom non défini',
      'saving': 'Enregistrement...',
      'language': 'Langue',
      'french': 'Français',
      'english': 'English',
      'languageChanged': 'Langue changée vers',
      'loadError': 'Erreur de chargement des données',
      'accountDeleted': 'Votre compte a été supprimé',
      'unknownRole': 'Rôle inconnu. Contactez l\'administrateur.',
      'loadingApp': 'Chargement de FLOSTAY...',
    },
    'en': {
      'myProfile': 'My Profile',
      'editProfile': 'Edit my profile',
      'fullName': 'Full name',
      'phone': 'Phone',
      'cancel': 'Cancel',
      'save': 'Save',
      'nameRequired': 'Name is required',
      'profileUpdated': 'Profile updated successfully!',
      'updateError': 'Error updating profile',
      'profilePhotoUpdated': 'Profile photo updated successfully',
      'updatePhotoError': 'Error updating photo',
      'imageTooLarge': 'Image is too large. Maximum: 5MB',
      'securityError': 'Security error. Check Supabase policies.',
      'accessDenied': 'Access denied. Check Supabase policies.',
      'supabaseSetupRequired': 'Supabase setup required',
      'supabaseSetupInstructions': 'For profile photos to work, you need to configure Supabase:',
      'supabaseStep1': 'Go to Storage → Buckets → profile_images',
      'supabaseStep2': 'Enable \'Public\' option for the bucket',
      'supabaseStep3': 'Configure security policies',
      'supabasePolicySelect': '- SELECT Policy: bucket_id = \'profile_images\' (for public)',
      'supabasePolicyInsert': '- INSERT Policy: bucket_id = \'profile_images\' AND (storage.foldername(name))[1] = auth.uid()::text (for authenticated)',
      'supabasePolicyUpdate': '- UPDATE Policy: Same condition as INSERT',
      'supabasePolicyDelete': '- DELETE Policy: Same condition as INSERT',
      'understand': 'I understand',
      'noUser': 'No user connected',
      'login': 'Login',
      'noName': 'Name not defined',
      'saving': 'Saving...',
      'language': 'Language',
      'french': 'Français',
      'english': 'English',
      'languageChanged': 'Language changed to',
      'loadError': 'Error loading data',
      'accountDeleted': 'Your account has been deleted',
      'unknownRole': 'Unknown role. Please contact administrator.',
      'loadingApp': 'Loading FLOSTAY...',
    },
  };

  String get myProfile => _localizedValues[locale.languageCode]!['myProfile']!;
  String get editProfile => _localizedValues[locale.languageCode]!['editProfile']!;
  String get fullName => _localizedValues[locale.languageCode]!['fullName']!;
  String get phone => _localizedValues[locale.languageCode]!['phone']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get save => _localizedValues[locale.languageCode]!['save']!;
  String get nameRequired => _localizedValues[locale.languageCode]!['nameRequired']!;
  String get profileUpdated => _localizedValues[locale.languageCode]!['profileUpdated']!;
  String get updateError => _localizedValues[locale.languageCode]!['updateError']!;
  String get profilePhotoUpdated => _localizedValues[locale.languageCode]!['profilePhotoUpdated']!;
  String get updatePhotoError => _localizedValues[locale.languageCode]!['updatePhotoError']!;
  String get imageTooLarge => _localizedValues[locale.languageCode]!['imageTooLarge']!;
  String get securityError => _localizedValues[locale.languageCode]!['securityError']!;
  String get accessDenied => _localizedValues[locale.languageCode]!['accessDenied']!;
  String get supabaseSetupRequired => _localizedValues[locale.languageCode]!['supabaseSetupRequired']!;
  String get supabaseSetupInstructions => _localizedValues[locale.languageCode]!['supabaseSetupInstructions']!;
  String get supabaseStep1 => _localizedValues[locale.languageCode]!['supabaseStep1']!;
  String get supabaseStep2 => _localizedValues[locale.languageCode]!['supabaseStep2']!;
  String get supabaseStep3 => _localizedValues[locale.languageCode]!['supabaseStep3']!;
  String get supabasePolicySelect => _localizedValues[locale.languageCode]!['supabasePolicySelect']!;
  String get supabasePolicyInsert => _localizedValues[locale.languageCode]!['supabasePolicyInsert']!;
  String get supabasePolicyUpdate => _localizedValues[locale.languageCode]!['supabasePolicyUpdate']!;
  String get supabasePolicyDelete => _localizedValues[locale.languageCode]!['supabasePolicyDelete']!;
  String get understand => _localizedValues[locale.languageCode]!['understand']!;
  String get noUser => _localizedValues[locale.languageCode]!['noUser']!;
  String get login => _localizedValues[locale.languageCode]!['login']!;
  String get noName => _localizedValues[locale.languageCode]!['noName']!;
  String get saving => _localizedValues[locale.languageCode]!['saving']!;
  String get language => _localizedValues[locale.languageCode]!['language']!;
  String get french => _localizedValues[locale.languageCode]!['french']!;
  String get english => _localizedValues[locale.languageCode]!['english']!;
  String get languageChanged => _localizedValues[locale.languageCode]!['languageChanged']!;
  String get loadError => _localizedValues[locale.languageCode]!['loadError']!;
  String get accountDeleted => _localizedValues[locale.languageCode]!['accountDeleted']!;
  String get unknownRole => _localizedValues[locale.languageCode]!['unknownRole']!;
  String get loadingApp => _localizedValues[locale.languageCode]!['loadingApp']!;

  String get localeName => locale.languageCode;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['fr', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}