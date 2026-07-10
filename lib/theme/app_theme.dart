import 'package:flutter/material.dart';

// 1. Ana Renk Paleti (Tüm Uygulama)
class AppColors {
  // --- Eski / Standart Uygulama Renkleri (Diğer sayfalar bozulmasın diye) ---
  static const Color primaryBlue = Color.fromARGB(255, 130, 177, 242);
  static const Color backgroundNavy = Color.fromARGB(255, 1, 19, 42);
  static const Color textWhite = Colors.white;
  static const Color surfaceNavy = Color.fromARGB(255, 10, 30, 55);

  // --- Yeni YRC Core Vizyonu Renkleri (Arena ve Neon Tasarımlar İçin) ---
  static const Color yrcBackground = Color(0xFF0B101A);
  static const Color yrcCardBg = Color(0xFF161F33);
  static const Color yrcAccent = Color(0xFFD4FF00); // Neon Volt
  static const Color yrcTextMain = Color(0xFFF8FAFC);
  static const Color yrcTextSec = Color(0xFF94A3B8);

  // --- Efektler ---
  static final List<BoxShadow> yrcNeonGlow = [
    BoxShadow(
      color: yrcAccent.withAlpha(77),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

// 2. Arena Ekranlarındaki Kodlar Bozulmasın Diye Köprü Sınıfı
// (Arena kodlarımız bu değişkenleri arıyor, onları doğrudan AppColors'a bağlıyoruz)
class YRCStyle {
  static const Color background = AppColors.yrcBackground;
  static const Color cardBg = AppColors.yrcCardBg;
  static const Color accent = AppColors.yrcAccent;
  static const Color textMain = AppColors.yrcTextMain;
  static const Color textSec = AppColors.yrcTextSec;
  static final List<BoxShadow> neonGlow = AppColors.yrcNeonGlow;
}

// 3. Global ThemeData (Material 3 Uyumlu)
class AppTheme {
  static ThemeData get customTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundNavy,
      primaryColor: AppColors.primaryBlue,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBlue,
        surface: AppColors.surfaceNavy,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundNavy,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textWhite),
        titleTextStyle: TextStyle(
          color: AppColors.textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Buton Tasarımı
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          // Açık mavi butonda lacivert yazı çok şık durur
          foregroundColor: AppColors.backgroundNavy,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      // Koşu Listesi Kartları
      cardTheme: CardTheme(
        color: AppColors.surfaceNavy,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
