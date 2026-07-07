import 'package:flutter/material.dart';

// 1. Yeni YRC Renk Paleti
class AppColors {
  static const Color primaryBlue = Color.fromARGB(
    255,
    130,
    177,
    242,
  ); // Açık Mavi (Seçili ikonlar, butonlar)
  static const Color backgroundNavy = Color.fromARGB(
    255,
    1,
    19,
    42,
  ); // Koyu Lacivert (Ana arkaplan)
  static const Color textWhite = Colors.white; // Beyaz (Metinler)

  // Kartlar ve alt menü için ana lacivertten bir tık daha açık bir ton
  static const Color surfaceNavy = Color.fromARGB(255, 10, 30, 55);
}

// 2. Global ThemeData
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
          foregroundColor:
              AppColors
                  .backgroundNavy, // Açık mavi butonda lacivert yazı çok şık durur
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
