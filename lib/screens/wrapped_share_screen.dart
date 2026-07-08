import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Standart YRC Renklerimiz
class YRCStyle {
  static const Color background = Color(0xFF0B101A);
  static const Color cardBg = Color(0xFF161F33);
  static const Color accent = Color(0xFFD4FF00); // Neon Volt
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textSec = Color(0xFF94A3B8);
}

class WrappedShareScreen extends StatelessWidget {
  const WrappedShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // İleride bu ekranı resme çevirmek için RepaintBoundary kullanılacak.
    return Scaffold(
      backgroundColor: Colors.black, // Story arka planı için tam siyah
      body: Center(
        child: AspectRatio(
          aspectRatio: 9 / 16, // Instagram Story tam boyutu
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B101A), // Koyu Lacivert
                  Color(0xFF000000), // Siyah
                ],
              ),
            ),
            child: Stack(
              children: [_buildBackgroundWatermark(), _buildContent()],
            ),
          ),
        ),
      ),
      // Ekrandan çıkmak için basit bir kapat butonu ve Paylaş butonu
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton.extended(
            heroTag: "btn1",
            onPressed: () => Navigator.pop(context),
            backgroundColor: YRCStyle.cardBg,
            label: const Text("KAPAT", style: TextStyle(color: Colors.white)),
          ),
          FloatingActionButton.extended(
            heroTag: "btn2",
            onPressed: () {
              HapticFeedback.heavyImpact();
              // Burada ekran fotosu alınıp Instagram'a yollanacak
            },
            backgroundColor: YRCStyle.accent,
            icon: const Icon(Icons.share, color: Colors.black),
            label: const Text(
              "HİKAYEYE AT",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Arka planda havalı ve silik bir YRC yazısı
  Widget _buildBackgroundWatermark() {
    return Positioned(
      right: -100,
      top: 100,
      child: Transform.rotate(
        angle: -0.2,
        child: Text(
          "YRC\nCORE",
          style: TextStyle(
            fontSize: 180,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.03),
            height: 0.9,
          ),
        ),
      ),
    );
  }

  // Asıl vurucu içerik
  Widget _buildContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "HAFTANIN\nŞAMPİYONU",
              style: TextStyle(
                color: YRCStyle.accent,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const Spacer(flex: 1),

            // Kullanıcı Bilgisi
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: YRCStyle.accent, width: 2),
                    image: const DecorationImage(
                      image: NetworkImage('https://i.pravatar.cc/150'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  "Ergün",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Vurucu Data
            const Text(
              "KATEGORİ",
              style: TextStyle(
                color: YRCStyle.textSec,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const Text(
              "5K RUN",
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "DERECE",
              style: TextStyle(
                color: YRCStyle.textSec,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const Text(
              "18:30",
              style: TextStyle(
                color: YRCStyle.accent,
                fontSize: 80,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const Text(
              "3:42 /KM PACE",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(flex: 2),

            // Bottom Branding
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: YRCStyle.accent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "yrccore.app",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60), // Butonlar için boşluk
          ],
        ),
      ),
    );
  }
}
