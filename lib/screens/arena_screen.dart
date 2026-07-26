// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/arena_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreRank {
  final int rank;
  final String name;
  final int score;
  final String avatarUrl;
  final bool isKing;

  ScoreRank({
    required this.rank,
    required this.name,
    required this.score,
    required this.avatarUrl,
    this.isKing = false,
  });
}

class BountyItem {
  final int id;
  final String title;
  final String description;
  final int rewardXp;
  final double progress; // 0.0 - 1.0 arası, görsel amaçlı
  final bool isCompleted; // backend'deki gerçek tamamlanma durumu

  BountyItem({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardXp,
    required this.progress,
    required this.isCompleted,
  });
}

class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  List<ScoreRank> _currentPodium = [];
  List<BountyItem> _bounties = [];
  bool _isLoading = true;

  int _myRank = 0;
  int _pointsToNext = 0;
  String _targetName = "...";
  bool _hasRunThisWeek = false;

  double _activeDays = 0.0;
  double _totalElev = 0.0;
  double _totalDist = 0.0;
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _fetchPerformanceData();
  }

  Future<void> _fetchPerformanceData() async {
    setState(() => _isLoading = true);

    // YENİ: Fonksiyonun tetiklendiğini kesin olarak görelim
    print("🚨 [ARENA DEBUG] 1. Fonksiyon tetiklendi!");

    try {
      final supabase = Supabase.instance.client;

      final prefs = await SharedPreferences.getInstance();
      final myStravaId = prefs.getInt('current_strava_id');

      print("🚨 [ARENA DEBUG] Current Strava ID: $myStravaId");

      if (myStravaId != null) {
        final statsData =
            await supabase
                .from('arena_weekly_stats')
                .select('active_days, total_distance_km, total_elevation')
                .eq('strava_id', myStravaId)
                .maybeSingle();

        print("🚨 [ARENA DEBUG] Stats Data: $statsData");

        if (statsData != null) {
          setState(() {
            _activeDays = (statsData['active_days'] as num?)?.toDouble() ?? 0.0;
            _totalDist =
                (statsData['total_distance_km'] as num?)?.toDouble() ?? 0.0;
            _totalElev =
                (statsData['total_elevation'] as num?)?.toDouble() ?? 0.0;
            _hasRunThisWeek = _activeDays > 0;
          });
          await _fetchBounties(myStravaId);
        }
      } else {
        print(
          "🚨 [ARENA DEBUG] KRİTİK HATA: User NULL geldi. Kullanıcı giriş yapmamış görünüyor.",
        );
      }

      // --- LİDERLİK PODYUMUNU ÇEKİYORUZ ---
      final List<dynamic> response = await supabase
          .from('arena_weekly_scores')
          .select()
          .order('yrc_score', ascending: false)
          .limit(3);

      if (response.isNotEmpty) {
        List<ScoreRank> fetched = [];
        for (int i = 0; i < response.length; i++) {
          final row = response[i];
          String firstName = row['first_name']?.toString() ?? 'Koşucu';
          int score = int.tryParse(row['yrc_score']?.toString() ?? '0') ?? 0;

          // DİNAMİK SIRALAMA: Podyumda kendi adımızı bulup sıramızı ve rakibi hesaplıyoruz
          if (firstName == 'Ergün') {
            _myRank = i + 1;
            if (i > 0) {
              int targetScore =
                  int.tryParse(
                    response[i - 1]['yrc_score']?.toString() ?? '0',
                  ) ??
                  0;
              _pointsToNext = targetScore - score;
              _targetName =
                  response[i - 1]['first_name']?.toString() ?? 'Rakip';
            }
          }

          fetched.add(
            ScoreRank(
              rank: i + 1,
              name: firstName,
              score: score,
              avatarUrl:
                  row['avatar_url'] ??
                  row['profile_url'] ??
                  'https://ui-avatars.com/api/?name=$firstName&background=82B1F2&color=fff',
              isKing: i == 0,
            ),
          );
        }
        if (mounted) {
          setState(() {
            _currentPodium = fetched;
            _isLoading = false;
          });
        } else {
          // YENİ: Bu hafta gerçekten kimse koşmamış — sahte veri göstermek yerine
          // podyumu boş bırakıyoruz, _buildPodium() zaten doğru mesajı gösterecek.
          if (mounted) {
            setState(() {
              _currentPodium = [];
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Supabase YRC Skor verisi çekilemedi: $e');
    }
  }

  Future<void> _fetchBounties(int stravaId) async {
    try {
      final supabase = Supabase.instance.client;

      // Postgres'teki date_trunc('week', now()) ile aynı mantık: haftanın Pazartesi'si
      final now = DateTime.now();
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));

      final definitions =
          await supabase.from('active_weekly_bounties').select();

      final completions = await supabase
          .from('user_bounty_completions')
          .select('bounty_id')
          .eq('strava_id', stravaId)
          .eq('week_start', weekStart.toIso8601String().split('T').first);

      final completedIds =
          (completions as List).map((c) => c['bounty_id'] as int).toSet();

      final List<BountyItem> fetched =
          (definitions as List).map((d) {
            final metricType = d['metric_type'] as String;
            final targetValue = (d['target_value'] as num).toDouble();

            double currentValue;
            switch (metricType) {
              case 'distance_km':
                currentValue = _totalDist;
                break;
              case 'elevation':
                currentValue = _totalElev;
                break;
              case 'active_days':
                currentValue = _activeDays;
                break;
              default:
                currentValue = 0.0;
            }

            final bountyId = d['id'] as int;
            final isCompleted = completedIds.contains(bountyId);

            return BountyItem(
              id: bountyId,
              title: d['title'] as String,
              description: d['description'] as String,
              rewardXp: d['reward_xp'] as int,
              progress: isCompleted ? 1.0 : (currentValue / targetValue),
              isCompleted: isCompleted,
            );
          }).toList();

      if (mounted) {
        setState(() => _bounties = fetched);
      }
    } catch (e) {
      debugPrint('Bounty verisi çekilemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.yrcBackground,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(),
                _buildPodium(),

                // --- YENİ EKLENEN KISIM BAŞLANGICI ---
                // Şimdilik StatusCard'ı statik değerlerle koyalım, sonraki adımda dinamik yapacağız.
                SliverToBoxAdapter(
                  child: ArenaStatusCard(
                    currentRank: _myRank,
                    pointsToNext: _pointsToNext,
                    targetName: _targetName,
                    hasRunThisWeek: _hasRunThisWeek,
                  ),
                ),

                _buildSectionTitle("YRC KONTRATLARI"),

                // Görev kartlarımıza SQL'den çektiğimiz canlı verileri paslıyoruz (Pass-down)
                SliverToBoxAdapter(
                  child: ArenaBountiesList(bounties: _bounties),
                ),
                // --- YENİ EKLENEN KISIM BİTİŞİ ---
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "YRC ARENA",
                style: TextStyle(
                  color: AppColors.yrcAccent,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "HAFTANIN\nPARLAYANLARI",
                style: TextStyle(
                  color: AppColors.yrcTextMain,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildPodium() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 250,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.yrcAccent),
          ),
        ),
      );
    }
    if (_currentPodium.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 250,
          child: Center(
            child: Text(
              "Bu hafta kimse koşmadı",
              style: TextStyle(
                color: AppColors.yrcTextSec,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
    ScoreRank? king = _currentPodium.isNotEmpty ? _currentPodium[0] : null;
    ScoreRank? second = _currentPodium.length > 1 ? _currentPodium[1] : null;
    ScoreRank? third = _currentPodium.length > 2 ? _currentPodium[2] : null;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 40,
          bottom: 24,
          left: 24,
          right: 24,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (second != null) Expanded(child: _podiumAvatar(second, 65, 20)),
            if (king != null) Expanded(child: _podiumAvatar(king, 100, 40)),
            if (third != null) Expanded(child: _podiumAvatar(third, 65, 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.yrcTextSec,
          letterSpacing: 2,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  Widget _podiumAvatar(ScoreRank rankUser, double size, double heightOffset) {
    return Padding(
      padding: EdgeInsets.only(bottom: heightOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        rankUser.isKing
                            ? AppColors.yrcAccent
                            : AppColors.yrcCardBg,
                    width: rankUser.isKing ? 4 : 2,
                  ),
                  boxShadow: rankUser.isKing ? AppColors.yrcNeonGlow : [],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: rankUser.avatarUrl,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(color: AppColors.yrcCardBg),
                    errorWidget:
                        (context, url, error) =>
                            const Icon(Icons.error, color: Colors.white24),
                  ),
                ),
              ),
              if (rankUser.isKing)
                Positioned(
                  top: -24,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.yrcCardBg,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.yrcNeonGlow,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.yrcAccent,
                      size: 24,
                    ),
                  ),
                ),
              Positioned(
                bottom: -10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color:
                        rankUser.isKing
                            ? AppColors.yrcAccent
                            : AppColors.yrcCardBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.yrcBackground,
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${rankUser.rank}",
                    style: TextStyle(
                      color: rankUser.isKing ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            rankUser.name,
            style: TextStyle(
              color:
                  rankUser.isKing
                      ? AppColors.yrcTextMain
                      : AppColors.yrcTextSec,
              fontWeight: FontWeight.bold,
              fontSize: rankUser.isKing ? 18 : 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "${rankUser.score} PTS",
            style: TextStyle(
              color: AppColors.yrcAccent,
              fontWeight: FontWeight.w900,
              fontSize: rankUser.isKing ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
