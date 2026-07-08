import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/shimmer_loading.dart';
import '../services/strava_service.dart';
import '../widgets/half_circle_progress.dart'; // Yeni Eklenen
import '../widgets/profile_stat_cards.dart'; // Yeni Eklenen

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

  // --- DİNAMİK VERİ DEĞİŞKENLERİ ---
  String _avatarUrl = '';
  String _fullName = 'YÜKLENİYOR...';

  final _weeklyGoal = 50.0;
  double _currentWeeklyKm = 0.0;

  String _avgPace = '--:-- /km';
  String _totalDuration = '--s --d';
  bool _isLoading = true;

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

      final userData =
          await supabase
              .from('users')
              .select('first_name, last_name, profile_url, strava_id')
              .limit(1)
              .maybeSingle();

      if (userData == null || userData['strava_id'] == null) {
        if (mounted) {
          setState(() {
            _fullName = 'Kayıt Bulunamadı';
            _isLoading = false;
          });
        }
        return;
      }

      final myStravaId = userData['strava_id'];
      final now = DateTime.now();
      final startOfWeekIso =
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday - 1)).toIso8601String();

      final activities = await supabase
          .from('activities')
          .select('distance_meters, moving_time')
          .eq('strava_id', myStravaId)
          .gte('start_date', startOfWeekIso);

      double totalKm = 0.0;
      int totalSeconds = 0;

      for (var run in activities) {
        totalKm += (run['distance_meters'] ?? 0) / 1000;
        totalSeconds += (run['moving_time'] ?? 0) as int;
      }

      String calculatedPace = '--:--';
      if (totalKm > 0) {
        int paceSeconds = (totalSeconds / totalKm).round();
        calculatedPace =
            '${paceSeconds ~/ 60}:${(paceSeconds % 60).toString().padLeft(2, '0')}';
      }

      if (mounted) {
        setState(() {
          _avatarUrl = userData['profile_url'] ?? '';
          _fullName =
              '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
                  .trim();
          if (_fullName.isEmpty) _fullName = 'İsimsiz Koşucu';

          _currentWeeklyKm = totalKm;
          _avgPace = '$calculatedPace /km';
          _totalDuration =
              '${totalSeconds ~/ 3600}s ${(totalSeconds % 3600) ~/ 60}d';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncStravaDataSilent() async {
    try {
      final supabase = Supabase.instance.client;
      final userData =
          await supabase
              .from('users')
              .select('strava_id, access_token')
              .limit(1)
              .maybeSingle();

      if (userData != null &&
          userData['strava_id'] != null &&
          userData['access_token'] != null) {
        await StravaService().syncRecentActivities(
          userData['access_token'],
          userData['strava_id'],
        );
      }
    } catch (e) {
      debugPrint('Sessiz senkronizasyon sırasında hata: $e');
    }
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

  Widget _buildProfileShimmer() {
    return ShimmerEffect(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonBox(width: 60, height: 60, borderRadius: 30),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 140, height: 18, borderRadius: 4),
                    SizedBox(height: 8),
                    SkeletonBox(width: 90, height: 14, borderRadius: 4),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Center(
              child: SkeletonBox(width: 240, height: 125, borderRadius: 62),
            ),
            const SizedBox(height: 40),
            const Row(
              children: [
                Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 96,
                    borderRadius: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 96,
                    borderRadius: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 96,
                    borderRadius: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 96,
                    borderRadius: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonBox(
              width: double.infinity,
              height: 80,
              borderRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(double progress) {
    return SingleChildScrollView(
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
                          color: Colors.white.withAlpha(127),
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
              StatCard(
                title: 'BU HAFTA (TOPLAM)',
                value: '${_currentWeeklyKm.toStringAsFixed(1)} km',
                icon: Icons.directions_run,
                color: neonBlue,
              ),
              const SizedBox(width: 16),
              StatCard(
                title: 'BU HAFTA (YRC İLE)',
                value: 'Yakında',
                icon: Icons.groups_rounded,
                color: stravaOrange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              StatCard(
                title: 'ORT. PACE (1 HFT)',
                value: _avgPace,
                icon: Icons.speed_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 16),
              StatCard(
                title: 'SÜRE (1 HFT)',
                value: _totalDuration,
                icon: Icons.timer_outlined,
                color: nikeVolt,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const WideStatCard(
            title: 'YRC ETKİNLİK KATILIMI',
            value: 'Çok Yakında',
            icon: Icons.local_activity_rounded,
            color: Colors.purpleAccent,
          ),
          const SizedBox(height: 40),
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
        child:
            _isLoading
                ? _buildProfileShimmer()
                : _buildProfileContent(progress),
      ),
    );
  }
}
