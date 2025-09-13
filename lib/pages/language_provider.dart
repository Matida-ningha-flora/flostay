import 'package:flutter/material.dart';

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('fr');

  Locale get currentLocale => _currentLocale;

  void setLocale(Locale newLocale) {
    _currentLocale = newLocale;
    notifyListeners();
  }
}