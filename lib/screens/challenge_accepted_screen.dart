import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class YRCStyle {
  static const Color background = Color(0xFF0B101A);
  static const Color cardBg = Color(0xFF161F33);
  static const Color accent = Color(0xFFD4FF00); // Neon Volt
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textSec = Color(0xFF94A3B8);
}

class ChallengeAcceptedScreen extends StatefulWidget {
  final String targetName;
  final String targetPace;
  final String distance;

  const ChallengeAcceptedScreen({
    super.key,
    this.targetName = "Ergün",
    this.targetPace = "18:30",
    this.distance = "5K",
  });

  @override
  State<ChallengeAcceptedScreen> createState() =>
      _ChallengeAcceptedScreenState();
}

class _ChallengeAcceptedScreenState extends State<ChallengeAcceptedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact(); // Ekrana girerken güçlü titreşim

    // Arkadaki "Radar / Dinliyor" animasyonu
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YRCStyle.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: YRCStyle.textMain, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTargetCard(),
              const SizedBox(height: 60),
              _buildSyncRadar(),
              const SizedBox(height: 60),
              _buildInstructions(),
              const SizedBox(height: 40),
              _buildActionButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: YRCStyle.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: YRCStyle.accent, width: 1),
      ),
      child: Column(
        children: [
          const Text(
            "MEYDAN OKUMA KABUL EDİLDİ",
            style: TextStyle(
              color: YRCStyle.accent,
              letterSpacing: 2,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.distance,
            style: const TextStyle(
              color: YRCStyle.textMain,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Hedef: ${widget.targetName} - ${widget.targetPace}",
            style: const TextStyle(color: YRCStyle.textSec, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncRadar() {
    // PERFORMANS OPTİMİZASYONU: RepaintBoundary eklendi.
    // İçerideki sonsuz animasyon (60fps), ekranın geri kalan statik
    // kısımlarını (yazılar, butonlar) yeniden çizdirmeyecek.
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dalgalanan arka plan 1 (Dış Çizgi / Border)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 1.5),
                child: Opacity(
                  opacity: (1.0 - _pulseController.value).clamp(0.0, 1.0),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: YRCStyle.accent, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),
          // Dalgalanan arka plan 2 (Dolu Yuvarlak)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.8 + (_pulseController.value * 0.4),
                child: Opacity(
                  opacity: (0.8 - (_pulseController.value * 0.8)).clamp(
                    0.0,
                    1.0,
                  ),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: YRCStyle.accent.withAlpha(51),
                    ),
                  ),
                ),
              );
            },
          ),
          // Sabit İkon (Merkez)
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: YRCStyle.cardBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.watch, color: YRCStyle.accent, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Column(
      children: const [
        Text(
          "SAATİNİ BAŞLAT",
          style: TextStyle(
            color: YRCStyle.textMain,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        Text(
          "Garmin, Apple Watch veya Strava'dan koşunu kaydet.\nSen bitirdiğinde verini otomatik çekeceğiz.",
          textAlign: TextAlign.center,
          style: TextStyle(color: YRCStyle.textSec, fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(
            context,
          ); // Hub'a geri döner, sistem arkada "bekleme" modundadır.
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: YRCStyle.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          "ANTRENMANA ÇIKIYORUM",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
