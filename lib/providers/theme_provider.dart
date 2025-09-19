import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    _loadThemePreference();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemePreference();
    notifyListeners();
  }

  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    _saveThemePreference();
    notifyListeners();
  }

  // Tema tercihini SharedPreferences'a kaydet
  void _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  // Tema tercihini SharedPreferences'tan yükle
  void _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getBool('isDarkMode');
      _isDarkMode = savedTheme ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Hata durumunda varsayılan değeri kullan (false = light mode)
      _isDarkMode = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Dark mode için tema
  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.black,
    fontFamily: 'Cormorant',
  );

  // Light mode için tema
  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: const Color(0xFFE5E2DB),
    fontFamily: 'Cormorant',
  );

  // Mevcut tema
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;
}
