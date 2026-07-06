import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// WidgetsBindingObserver ekleyerek uygulamanın açılıp kapanmasını dinliyoruz
class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  // Temel Renklerimiz
  final Color stravaOrange = const Color(0xFFFC4C02);
  final Color nikeVolt = const Color(0xFFCEFF00);
  final Color neonBlue = const Color(0xFF82B1F2);
  final Color cardColor = const Color(0xFF0A121F);
  final Color cardBorder = Colors.white.withOpacity(0.05);

  @override
  void initState() {
    super.initState();
    // Uygulama durumunu dinlemeye başlıyoruz
    WidgetsBinding.instance.addObserver(this);

    // Sayfa ilk açıldığında sessizce verileri güncelle
    _loadUserStats();
    _syncStravaDataSilent();
  }

  @override
  void dispose() {
    // Sayfa kapanırsa dinlemeyi bırakıyoruz (Hafıza sızıntısını önler)
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // UYGULAMA ARKA PLANDAN ÖN PLANA ÇIKTIĞINDA ÇALIŞIR
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("Uygulamaya dönüldü, veriler arka planda güncelleniyor...");
      _syncStravaDataSilent();
      _loadUserStats();
    }
  }

  Future<void> _loadUserStats() async {
    // Backend veri çekme simülasyonu
  }

  Future<void> _syncStravaDataSilent() async {
    // Strava arka plan senkronizasyon simülasyonu
  }

  // Kullanıcı ekranı aşağı kaydırdığında çalışacak fonksiyon (Pull-to-Refresh)
  Future<void> _onRefresh() async {
    await _syncStravaDataSilent();
    await _loadUserStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veriler güncellendi! 🏃‍♂️'),
          backgroundColor: stravaOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Standart Kare İstatistik Kartı
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Geniş (Full-width) İstatistik Kartı
  Widget _buildWideStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Örnek Parametreler (İleride Backend'den dolacak)
    double weeklyGoal = 50.0;
    double currentWeeklyKm = 32.5;
    double progress = (currentWeeklyKm / weeklyGoal).clamp(0.0, 1.0);

    return SafeArea(
      child: RefreshIndicator(
        color: nikeVolt,
        backgroundColor: cardColor,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KULLANICI BİLGİLERİ (Küçültüldü ve toparlandı)
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: stravaOrange,
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(
                        'https://i.pravatar.cc/150',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ERGÜN ÜNGÖR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'YRC | Pacer',
                        style: TextStyle(
                          color: stravaOrange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // 2. APPLE FITNESS TARZI YARIM DAİRE HEDEF GRAFİĞİ (Nefes Alan Tasarım)
              Center(
                child: SizedBox(
                  // Genişlik ve yüksekliği biraz daha derli toplu hale getirdik
                  width: 240,
                  height: 125,
                  child: CustomPaint(
                    painter: HalfCircleProgressPainter(
                      progress: progress,
                      progressColor: nikeVolt,
                      backgroundColor: Colors.white.withAlpha(127),
                    ),
                    // Yazıları grafiğin tepesinden uzaklaştırıp alt merkeze oturtmak için Padding ekledik
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 1.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'HAFTALIK HEDEF',
                            style: TextStyle(
                              color: Colors.white.withAlpha(127),
                              fontSize:
                                  11, // 13'ten 11'e düşürdük, daha zarif oldu
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(
                            height: 2,
                          ), // Metinlerin arasını biraz sıkılaştırdık
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                currentWeeklyKm.toStringAsFixed(1),
                                style: TextStyle(
                                  color: nikeVolt,
                                  fontSize:
                                      34, // 42 çok devasaydı, 34 ile yaya olan mesafeyi açtık
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    // Metnin kendi parlamasını da biraz yumuşattık ki yay ile karışmasın
                                    Shadow(
                                      color: nikeVolt.withOpacity(0.4),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                ' / ${weeklyGoal.toInt()} km',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16, // 18'den 16'ya çektik
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 3. PARAMETRELER IZGARASI (6 Adet Metrik)

              // Satır 1: Hafta Toplam Km & YRC ile Km
              Row(
                children: [
                  _buildStatCard(
                    'BU HAFTA (TOPLAM)',
                    '32.5 km',
                    Icons.directions_run,
                    neonBlue,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'BU HAFTA (YRC İLE)',
                    '15.0 km',
                    Icons.groups_rounded,
                    stravaOrange,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Satır 2: Ort Pace & Koşu Süresi
              Row(
                children: [
                  _buildStatCard(
                    'ORT. PACE (1 HFT)',
                    '4:45 /km',
                    Icons.speed_rounded,
                    Colors.white,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'SÜRE (1 HFT)',
                    '3s 15d',
                    Icons.timer_outlined,
                    nikeVolt,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Satır 3: YRC Etkinlik Katılımı (Geniş Kart)
              _buildWideStatCard(
                'YRC ETKİNLİK KATILIMI',
                '4 Aktivite',
                Icons.local_activity_rounded,
                Colors.purpleAccent,
              ),

              const SizedBox(height: 40), // Alt navigasyona pay
            ],
          ),
        ),
      ),
    );
  }
}

// APPLE FITNESS TARZI YARIM DAİRE ÇİZİCİSİ (NEON GLOW EFEKTLİ)
class HalfCircleProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;

  HalfCircleProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Çizgiyi biraz incelttik, grafiğe zarafet kattı (Eski: 18.0)
    double strokeWidth = 15.0;

    Rect rect = Rect.fromLTWH(0, strokeWidth / 2, size.width, size.height * 2);

    Paint backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    Paint shadowPaint =
        Paint()
          ..color = progressColor.withOpacity(0.4)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            12,
          ); // Blur yelpazesini bir tık daralttık

    Paint progressPaint =
        Paint()
          ..color = progressColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, backgroundPaint);

    if (progress > 0) {
      canvas.drawArc(rect, math.pi, math.pi * progress, false, shadowPaint);
      canvas.drawArc(rect, math.pi, math.pi * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
