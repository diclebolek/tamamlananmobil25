import 'package:flutter/material.dart';

class SiriusColors {
  // WEB3'teki ana renkler
  static const Color background = Color(0xFF0C0B09); // --background-color
  // Surface artık dinamik: isletme.tema_rengi2 ile güncellenir
  static Color get surface => accent2Dynamic; // --surface-color
  // Accent artık sabit: #228ae6 rengi kullanılıyor
  static const Color accent = Color(0xFF228AE6); // --accent-color (sabit mavi)
  static const Color heading = Color(0xFFFFFFFF); // --heading-color (beyaz)
  static const Color defaultText = Color(
    0xB3FFFFFF,
  ); // --default-color (beyaz 70%)
  static const Color contrast = Color(0xFF0C0B09); // --contrast-color

  // Sabit tema rengi (#228ae6)
  static const Color accentDynamic = Color(0xFF228AE6);

  // İkinci tema rengi artık sabit: #232729 rengi kullanılıyor (koyu gri surface)
  static Color accent2Dynamic = const Color(0xFF232729);
  static Color get accent2 => accent2Dynamic;

  // Dışarıdan dinamik ana rengi ayarlamak için yardımcı (artık kullanılmıyor)
  static void setAccentDynamic(Color color) {
    // Artık kullanılmıyor - sabit renk kullanılıyor
  }

  // Ek renkler
  static const Color lightBackground = Color(0xFF241F29); // .light-background
  static const Color darkBackground = Color(0xFF000000); // .dark-background
  static const Color surfaceLight = Color(
    0xFF413546,
  ); // .light-background surface

  // Durum renkleri
  static const Color success = Color(0xFF4CAF50); // Başarı rengi
  static const Color error = Color(0xFFF44336); // Hata rengi
  static const Color warning = Color(0xFFFF9800); // Uyarı rengi
  static const Color info = Color(0xFF2196F3); // Bilgi rengi

  // Border ve çizgi renkleri
  static const Color border = Color(0xFF413546); // Kenarlık rengi
}
