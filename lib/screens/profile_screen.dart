import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  // --- TEMEL RENKLER ---
  final Color stravaOrange = const Color(0xFFFC4C02);
  final Color nikeVolt = const Color(0xFFCEFF00);
  final Color neonBlue = const Color(0xFF82B1F2);
  final Color cardColor = const Color(0xFF0A121F);
  final Color cardBorder = Colors.white.withAlpha(
    (0.5 * 255).round(),
  ); // Opaklığı %50 olarak ayarladık

  // --- DİNAMİK VERİ DEĞİŞKENLERİ ---
  String _avatarUrl = '';
  String _fullName = 'YÜKLENİYOR...';

  final _weeklyGoal = 50.0;
  double _currentWeeklyKm = 0.0;

  String _avgPace = '--:-- /km';
  String _totalDuration = '--s --d';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadUserStats();
    _syncStravaDataSilent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncStravaDataSilent();
      _loadUserStats();
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. KULLANICI BİLGİLERİNİ ÇEK
      final userData =
          await supabase
              .from('users')
              .select('first_name, last_name, profile_url, strava_id')
              .limit(1)
              .maybeSingle();

      if (userData == null || userData['strava_id'] == null) {
        debugPrint('Kullanıcı veya strava_id bulunamadı!');
        if (mounted) {
          setState(() {
            _fullName = 'Kayıt Bulunamadı';
          });
        }
        return;
      }

      final myStravaId = userData['strava_id'];

      // 2. BU HAFTANIN PAZARTESİ GÜNÜNÜ BUL
      final now = DateTime.now();
      // now.weekday: Pazartesi = 1, Salı = 2 ... Pazar = 7
      // İçinde bulunduğumuz günden (weekday - 1) kadar gün çıkarırsak tam Pazartesiye ulaşırız.
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final startOfWeekIso =
          startOfWeek.toIso8601String(); // Pazartesi 00:00:00

      // 3. PAZARTESİDEN İTİBAREN OLAN AKTİVİTELERİ ÇEK
      final activities = await supabase
          .from('activities')
          .select('distance_meters, moving_time')
          .eq('strava_id', myStravaId)
          .gte(
            'start_date',
            startOfWeekIso,
          ); // Sadece bu haftanın başından itibaren!

      double totalKm = 0.0;
      int totalSeconds = 0;

      for (var run in activities) {
        totalKm += (run['distance_meters'] ?? 0) / 1000;
        totalSeconds += (run['moving_time'] ?? 0) as int;
      }

      // Pace (Hız) Hesaplama
      String calculatedPace = '--:--';
      if (totalKm > 0) {
        int paceSeconds = (totalSeconds / totalKm).round();
        int minutes = paceSeconds ~/ 60;
        int seconds = paceSeconds % 60;
        calculatedPace = '$minutes:${seconds.toString().padLeft(2, '0')}';
      }

      // Süre Hesaplama
      int hours = totalSeconds ~/ 3600;
      int mins = (totalSeconds % 3600) ~/ 60;

      // Ekrana Verileri Bas
      if (mounted) {
        setState(() {
          _avatarUrl = userData['profile_url'] ?? '';
          _fullName =
              '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
                  .trim();
          if (_fullName.isEmpty) _fullName = 'İsimsiz Koşucu';

          _currentWeeklyKm = totalKm;
          _avgPace = '$calculatedPace /km';
          _totalDuration = '${hours}s ${mins}d';
        });
      }
    } catch (e) {
      debugPrint('Veri çekilirken hata oluştu: $e');
    }
  }

  Future<void> _syncStravaDataSilent() async {
    // Strava API'den arka planda son koşuları getiren kod
  }

  Future<void> _onRefresh() async {
    await _syncStravaDataSilent();
    await _loadUserStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veriler başarıyla güncellendi!'),
          backgroundColor: stravaOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
                color: Colors.white.withAlpha((0.5 * 255).round()),
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
              color: color.withAlpha((0.1 * 255).round()),
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
                    color: Colors.white.withAlpha((0.5 * 255).round()),
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
    double progress =
        _weeklyGoal > 0
            ? (_currentWeeklyKm / _weeklyGoal).clamp(0.0, 1.0)
            : 0.0;

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
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: stravaOrange,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(
                        _avatarUrl.isNotEmpty
                            ? _avatarUrl
                            : 'https://ui-avatars.com/api/?name=${_fullName.replaceAll(' ', '+')}&background=FC4C02&color=fff',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullName,
                        style: const TextStyle(
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

              Center(
                child: SizedBox(
                  width: 240,
                  height: 125,
                  child: CustomPaint(
                    painter: HalfCircleProgressPainter(
                      progress: progress,
                      progressColor: nikeVolt,
                      backgroundColor: Colors.white.withAlpha(127),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 1.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'HAFTALIK HEDEF',
                            style: TextStyle(
                              color: Colors.white.withAlpha((127).round()),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _currentWeeklyKm.toStringAsFixed(1),
                                style: TextStyle(
                                  color: nikeVolt,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: nikeVolt.withAlpha(
                                        (0.4 * 255).round(),
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                ' / ${_weeklyGoal.toInt()} km',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
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

              Row(
                children: [
                  _buildStatCard(
                    'BU HAFTA (TOPLAM)',
                    '${_currentWeeklyKm.toStringAsFixed(1)} km',
                    Icons.directions_run,
                    neonBlue,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'BU HAFTA (YRC İLE)',
                    'Yakında', // <-- Placeholder eklendi
                    Icons.groups_rounded,
                    stravaOrange,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  _buildStatCard(
                    'ORT. PACE (1 HFT)',
                    _avgPace,
                    Icons.speed_rounded,
                    Colors.white,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'SÜRE (1 HFT)',
                    _totalDuration,
                    Icons.timer_outlined,
                    nikeVolt,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildWideStatCard(
                'YRC ETKİNLİK KATILIMI',
                'Çok Yakında', // <-- Placeholder eklendi
                Icons.local_activity_rounded,
                Colors.purpleAccent,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

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
          ..color = progressColor.withAlpha((0.4 * 255).round())
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

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
