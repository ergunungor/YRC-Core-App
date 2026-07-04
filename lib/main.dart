import 'package:flutter/material.dart';

void main() {
  // Uygulamanın motorunu çalıştıran ilk komut
  runApp(const YRCCoreApp());
}

class YRCCoreApp extends StatelessWidget {
  const YRCCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YRC Core',
      debugShowCheckedModeBanner:
          false, // Sağ üstteki "DEBUG" yazısını kaldırır
      theme: ThemeData(
        // Ana arka planı o bahsettiğimiz tok gece mavisi yapıyoruz
        scaffoldBackgroundColor: const Color(0xFF0B192C),
        // Uygulamanın genel renk şeması
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B192C),
          brightness:
              Brightness
                  .dark, // Yazıların otomatik beyaz/açık renk olmasını sağlar
        ),
      ),
      // Uygulama açıldığında görünecek ilk ekran (Şimdilik test ekranı)
      home: const Scaffold(
        body: Center(
          child: Text(
            'YRC Core Hazır 🏃‍♂️',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
