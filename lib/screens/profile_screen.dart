import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/shimmer_loading.dart';
import '../services/strava_service.dart';
import '../services/pacer_service.dart';
import '../widgets/half_circle_progress.dart'; // Yeni Eklenen
import '../widgets/profile_stat_cards.dart'; // Yeni Eklenen
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/event_repository.dart';

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

  final PacerService _pacerService = PacerService();

  // --- DİNAMİK VERİ DEĞİŞKENLERİ ---
  String _avatarUrl = '';
  String _fullName = 'YÜKLENİYOR...';

  double _weeklyGoal = 15.0;
  double _currentWeeklyKm = 0.0;
  int? _myStravaId;

  String _avgPace = '--:-- /km';
  String _totalDuration = '--s --d';
  bool _isLoading = true;

  // YENİ: Pacer rütbesi ve başvuru durumu
  String _myRole = 'user'; // 'user' | 'pacer' | 'admin'
  String? _pacerApplicationStatus; // null | 'pending' | 'approved' | 'rejected'
  bool _isApplyingForPacer = false;
  // YENİ: XP / Level sistemi
  int _totalXp = 0;
  int _currentLevel = 1;
  int _currentLevelThreshold = 0;
  int _nextLevelThreshold =
      100; // sıfıra bölünmeyi engellemek için güvenli varsayılan
  String _currentLevelBadgeName = '';

  double _weeklyYrcKm = 0;
  int _totalYrcParticipation = 0;

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

      final prefs = await SharedPreferences.getInstance();
      final myStravaId = prefs.getInt('current_strava_id');

      if (myStravaId == null) return;

      final userData =
          await supabase
              .from('users')
              .select(
                'first_name, last_name, profile_url, strava_id, weekly_goal, avatar_url, role',
              )
              .eq('strava_id', myStravaId)
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
      _myStravaId = userData['strava_id'];

      final yrcStats =
          await supabase
              .from('yrc_participation_alltime')
              .select('total_runs_count')
              .eq('strava_id', myStravaId)
              .maybeSingle();

      final weeklyYrcStats =
          await supabase
              .from('yrc_weekly_stats')
              .select('weekly_distance_km')
              .eq('strava_id', myStravaId)
              .maybeSingle();

      // Eğer veritabanında weekly_goal varsa onu al, yoksa 15.0 kullan
      if (mounted) {
        setState(() {
          _weeklyYrcKm =
              (weeklyYrcStats?['weekly_distance_km'] as num?)?.toDouble() ?? 0;

          _totalYrcParticipation =
              (yrcStats?['total_runs_count'] as num?)?.toInt() ?? 0;
          _weeklyGoal =
              double.tryParse(userData['weekly_goal']?.toString() ?? '15') ??
              15.0;
        });
      }

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

      // YENİ: Rol bilgisini oku
      final String role = userData['role'] as String? ?? 'user';

      // YENİ: Eğer henüz pacer/admin değilse, en son başvurusunun durumunu çek
      String? applicationStatus;
      if (role != 'pacer' && role != 'admin') {
        applicationStatus = await _pacerService.getMyLatestApplicationStatus(
          myStravaId,
        );
      }

      if (mounted) {
        setState(() {
          _avatarUrl = userData['avatar_url'] ?? userData['profile_url'] ?? '';
          _fullName =
              '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
                  .trim();
          if (_fullName.isEmpty) _fullName = 'İsimsiz Koşucu';

          _currentWeeklyKm = totalKm;
          _avgPace = '$calculatedPace /km';
          _totalDuration =
              '${totalSeconds ~/ 3600}s ${(totalSeconds % 3600) ~/ 60}d';
          _myRole = role;
          _pacerApplicationStatus = applicationStatus;
          _isLoading = false;
        });
      }
      await _fetchGamificationStats(myStravaId);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncStravaDataSilent() async {
    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final myStravaId = prefs.getInt('current_strava_id');

      if (myStravaId == null) return;

      final userData =
          await supabase
              .from('users')
              .select('strava_id, access_token')
              .eq('strava_id', myStravaId)
              .maybeSingle();

      if (userData != null &&
          userData['strava_id'] != null &&
          userData['access_token'] != null) {
        await StravaService().syncRecentActivities(
          userData['access_token'],
          userData['strava_id'],
        );
        await EventRepository().runEventBasedVerification(
          userData['strava_id'],
        );
      }
    } catch (e) {
      debugPrint('Sessiz senkronizasyon sırasında hata: $e');
    }
  }

  Future<void> _fetchGamificationStats(int stravaId) async {
    try {
      final supabase = Supabase.instance.client;

      final statsData =
          await supabase
              .from('user_gamification_stats')
              .select('total_xp, current_level, last_seen_level')
              .eq('strava_id', stravaId)
              .maybeSingle();

      if (statsData == null) return;

      final int totalXp = (statsData['total_xp'] as num?)?.toInt() ?? 0;
      final int currentLevel =
          (statsData['current_level'] as num?)?.toInt() ?? 1;

      final currentThresholdData =
          await supabase
              .from('level_thresholds')
              .select('required_xp')
              .eq('level', currentLevel)
              .maybeSingle();

      final nextThresholdData =
          await supabase
              .from('level_thresholds')
              .select('required_xp')
              .eq('level', currentLevel + 1)
              .maybeSingle();

      final int currentThreshold =
          (currentThresholdData?['required_xp'] as num?)?.toInt() ?? 0;
      final int nextThreshold =
          (nextThresholdData?['required_xp'] as num?)?.toInt() ??
          (currentThreshold + 1);

      final badgeData =
          await supabase
              .from('level_badges')
              .select('badge_name')
              .eq('level', currentLevel)
              .maybeSingle();
      final String badgeName = badgeData?['badge_name'] as String? ?? '';

      debugPrint('current_level: $currentLevel, badgeData: $badgeData');

      final int lastSeenLevel =
          (statsData['last_seen_level'] as num?)?.toInt() ?? 1;

      if (mounted) {
        setState(() {
          _totalXp = totalXp;
          _currentLevel = currentLevel;
          _currentLevelThreshold = currentThreshold;
          _nextLevelThreshold = nextThreshold;
          _currentLevelBadgeName = badgeName;
        });

        if (currentLevel > lastSeenLevel) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showLevelUpDialog(currentLevel, stravaId);
          });
        }
      }
    } catch (e) {
      debugPrint('Gamification verisi çekilemedi: $e');
    }
  }

  void _showLevelUpDialog(int newLevel, int stravaId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: nikeVolt.withAlpha(80), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: nikeVolt.withAlpha(60),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, color: nikeVolt, size: 56),
                const SizedBox(height: 16),
                Text(
                  'LEVEL ATLADIN!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'LEVEL $newLevel',
                  style: TextStyle(
                    color: nikeVolt,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: nikeVolt.withAlpha(100), blurRadius: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _showBadgeUnlockDialog(newLevel, stravaId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nikeVolt,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'DEVAM ET',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBadgeUnlockDialog(int newLevel, int stravaId) async {
    String badgeName = 'Yeni Rozet';
    try {
      final badgeData =
          await Supabase.instance.client
              .from('level_badges')
              .select('badge_name')
              .eq('level', newLevel)
              .maybeSingle();
      if (badgeData != null && badgeData['badge_name'] != null) {
        badgeName = badgeData['badge_name'] as String;
      }
    } catch (e) {
      debugPrint('Rozet bilgisi çekilemedi: $e');
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: nikeVolt.withAlpha(80), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: nikeVolt.withAlpha(60),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YENİ ROZET AÇILDI!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 20),
                Image.asset(
                  'assets/images/badges/level_$newLevel.png',
                  width: 140,
                  height: 140,
                  errorBuilder:
                      (context, error, stackTrace) => Icon(
                        Icons.military_tech_rounded,
                        color: nikeVolt,
                        size: 100,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  badgeName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: nikeVolt,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _markLevelSeen(stravaId, newLevel);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nikeVolt,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'HARİKA!',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markLevelSeen(int stravaId, int newLevel) async {
    try {
      await Supabase.instance.client
          .from('user_gamification_stats')
          .update({'last_seen_level': newLevel})
          .eq('strava_id', stravaId);
    } catch (e) {
      debugPrint('last_seen_level güncellenemedi: $e');
    }
  }

  // YENİ: Pacer'a başvuru fonksiyonu
  Future<void> _applyForPacer() async {
    if (_myStravaId == null) return;

    setState(() => _isApplyingForPacer = true);

    try {
      await _pacerService.applyForPacer(_myStravaId!);
      if (mounted) {
        setState(() {
          _pacerApplicationStatus = 'pending';
          _isApplyingForPacer = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: const Color(0xFF34C759),
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pacer başvurunuz başarıyla alındı.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplyingForPacer = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.red.shade400,
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.toString().replaceFirst('Exception: ', ''),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    await _syncStravaDataSilent();
    await _loadUserStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: stravaOrange,
          content: const Row(
            children: [
              Icon(Icons.sync_alt_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Veriler başarıyla güncellendi.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
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

  void _showGoalSelector() {
    // Hedef listesini 40'a kadar genişlettik
    final List<int> goalOptions = [5, 10, 15, 20, 25, 30, 35, 40];

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      // Yuvarlatılmış üst köşeler
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(
            top: 12,
            left: 24,
            right: 24,
            bottom: 20,
          ),
          // OPTİMİZASYON 1: Yüksekliği 180'e sabitleyerek alttaki gereksiz boşluğu tamamen yok ettik
          height: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OPTİMİZASYON 2: Üste premium uygulamalardaki drag barı (tutamacı) yerleştirdik
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'HAFTALIK HEDEFİNİ SEÇ',
                style: TextStyle(
                  color: Colors.white.withAlpha(140),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // OPTİMİZASYON 3: Yana kaydırılabilir yatay listeyi kurduk
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics:
                      const BouncingScrollPhysics(), // iOS tarzı premium esneme efekti
                  itemCount: goalOptions.length,
                  itemBuilder: (context, index) {
                    int goal = goalOptions[index];
                    bool isSelected = _weeklyGoal == goal;

                    return GestureDetector(
                      onTap: () async {
                        // 1. Önce ekranı anında güncelle ki kullanıcı beklemesin (Optimistic UI)
                        setState(() {
                          _weeklyGoal = goal.toDouble();
                        });
                        Navigator.pop(context); // Menüyü kapat

                        // 2. Arka planda veritabanına kaydet
                        if (_myStravaId != null) {
                          try {
                            await Supabase.instance.client
                                .from('users')
                                .update({'weekly_goal': goal})
                                .eq('strava_id', _myStravaId!);
                          } catch (e) {
                            debugPrint('Hedef güncellenirken hata oluştu: $e');
                          }
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 65, // Kartların ideal genişliği
                        margin: const EdgeInsets.only(right: 12, bottom: 6),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? nikeVolt
                                  : Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(
                            20,
                          ), // Yumuşatılmış köşe hatları
                          border: Border.all(
                            color:
                                isSelected
                                    ? nikeVolt
                                    : Colors.white.withAlpha(25),
                            width: 1.5,
                          ),
                          // OPTİMİZASYON 4: Seçili karta hafif bir neon glow (parlama) efekti verdik
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: nikeVolt.withAlpha(60),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                  : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$goal',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'km',
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.black54
                                        : Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // YENİ: Pacer başvuru butonu / durum göstergesi
  Widget _buildPacerApplicationSection() {
    // Zaten pacer veya admin ise hiçbir şey gösterme
    if (_myRole == 'pacer' || _myRole == 'admin') {
      return const SizedBox.shrink();
    }

    // Bekleyen bir başvurusu varsa durum göster
    if (_pacerApplicationStatus == 'pending') {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: Colors.white.withValues(alpha: 0.35),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'Pacer Başvurun İnceleniyor',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    /// Başvuru yok veya reddedilmiş: küçük, göze batmayan bir link
    return Center(
      child: TextButton(
        onPressed: _isApplyingForPacer ? null : _applyForPacer,
        child:
            _isApplyingForPacer
                ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                )
                : Text(
                  _pacerApplicationStatus == 'rejected'
                      ? 'Tekrar Pacer\'lığa Başvur'
                      : 'Pacer mısın? Başvur',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
      ),
    );
  }

  // YENİ: Sağ üst köşede statik rütbe rozeti
  Widget _buildRankBadge() {
    return Image.asset(
      'assets/images/badges/level_$_currentLevel.png',
      width: 44,
      height: 44,
      errorBuilder:
          (context, error, stackTrace) =>
              Icon(Icons.military_tech_rounded, color: nikeVolt, size: 32),
    );
  }

  // YENİ: XP İlerleme Çubuğu
  Widget _buildXpBar() {
    final int xpIntoLevel = _totalXp - _currentLevelThreshold;
    final int xpForLevel = _nextLevelThreshold - _currentLevelThreshold;
    final double safeProgress =
        xpForLevel > 0 ? (xpIntoLevel / xpForLevel).clamp(0.0, 1.0) : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentLevelBadgeName.isNotEmpty
                    ? 'LEVEL $_currentLevel | $_currentLevelBadgeName'
                    : 'LEVEL $_currentLevel',
                style: TextStyle(
                  color: nikeVolt,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '$_totalXp / $_nextLevelThreshold XP',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: safeProgress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: nikeVolt,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: nikeVolt.withAlpha(100), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        _myRole == 'pacer'
                            ? 'YRC | Pacer'
                            : _myRole == 'admin'
                            ? 'YRC | Admin'
                            : 'YRC | Üye',
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
              _buildRankBadge(),
            ],
          ),
          const SizedBox(height: 16),
          _buildXpBar(),
          const SizedBox(height: 24),
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
                          GestureDetector(
                            onTap: _showGoalSelector,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '/ ${_weeklyGoal.toInt()} km ▾',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                value: '${_weeklyYrcKm.toStringAsFixed(1)} km',
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
          WideStatCard(
            title: 'YRC ETKİNLİK KATILIMI',
            value: '$_totalYrcParticipation',
            icon: Icons.local_activity_rounded,
            color: Colors.purpleAccent,
          ),
          const SizedBox(height: 16),
          _buildPacerApplicationSection(),
          const SizedBox(height: 32),

          Center(
            child: TextButton.icon(
              onPressed: () async {
                try {
                  // 1. Gerçek oturum bilgimiz (Strava ID) SharedPreferences'ta —
                  // Supabase'in kendi Auth sistemini kullanmıyoruz, o yüzden
                  // asıl silmemiz gereken şey bu.
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('current_strava_id');

                  if (!mounted) return;
                  // 2. Kullanıcıyı Giriş (Auth) ekranına fırlat ve geri dönmesini engelle

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                } catch (e) {
                  debugPrint("Çıkış yapılırken hata oluştu: $e");
                }
              },
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              label: const Text(
                'OTURUMU KAPAT',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: Colors.redAccent.withAlpha(
                  25,
                ), // Hafif kırmızı arka plan
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Colors.redAccent.withAlpha(50),
                  ), // İnce kırmızı çerçeve
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
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
