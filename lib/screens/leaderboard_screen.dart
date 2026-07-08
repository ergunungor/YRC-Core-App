import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/shimmer_loading.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

// Yeni oluşturduğumuz dosyaları import ediyoruz
import '../models/runner_rank.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/runner_cards.dart';

enum LeaderboardState { loading, loaded, empty, error }

enum LeaderboardTab { totalWeekly, yrcOnly }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // --- YRC PREMIUM RENK PALETİ ---
  final Color neonBlue = const Color(0xFF82B1F2);
  final Color cardBgColor = const Color(0xFF132035);
  final Color mainBgColor = const Color(0xFF0A121F);

  // --- STATE DEĞİŞKENLERİ ---
  LeaderboardState _currentState = LeaderboardState.loading;
  LeaderboardTab _activeTab = LeaderboardTab.totalWeekly;
  List<RunnerRank> _runners = [];
  String _errorMessage = '';

  int _totalParticipants = 0;
  double _totalClubDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboardData();
  }

  Future<void> _fetchLeaderboardData() async {
    if (!mounted) return;
    setState(() => _currentState = LeaderboardState.loading);

    try {
      final supabase = Supabase.instance.client;

      // 1. Aktif kullanıcının Strava ID'sini öğreniyoruz
      final userData =
          await supabase
              .from('users')
              .select('strava_id')
              .limit(1)
              .maybeSingle();

      int? myStravaId;
      if (userData != null && userData['strava_id'] != null) {
        myStravaId = int.tryParse(userData['strava_id'].toString());
      }

      if (_activeTab == LeaderboardTab.totalWeekly) {
        // --- OPTİMİZASYON 1: Sadece ilk 30'u ve gerçek rank'i çek ---
        final List<dynamic> topRunnersData = await supabase
            .from('weekly_leaderboard_ranked')
            .select()
            .order('real_rank', ascending: true)
            .limit(30);

        List<RunnerRank> fetchedRunners = [];
        bool isCurrentUserInTop30 = false;
        RunnerRank? myRunnerData;

        // Toplamları hesaplamak için geçici değişkenler (İleride bunu da DB'ye yaptırabiliriz)
        double totalClubKm = 0.0;

        for (int i = 0; i < topRunnersData.length; i++) {
          final row = topRunnersData[i];

          double distanceKm =
              double.tryParse(row['total_distance_km']?.toString() ?? '0') ??
              0.0;
          int totalSeconds =
              int.tryParse(
                row['total_moving_time_seconds']?.toString() ?? '0',
              ) ??
              0;
          int runsCount =
              int.tryParse(row['runs_count']?.toString() ?? '0') ?? 0;

          // Veritabanından gelen GERÇEK sırayı alıyoruz
          int realRank =
              int.tryParse(row['real_rank']?.toString() ?? '0') ?? (i + 1);

          totalClubKm += distanceKm;

          String formattedPace = '--:--';
          if (distanceKm > 0 && totalSeconds > 0) {
            int paceSeconds = (totalSeconds / distanceKm).round();
            formattedPace =
                '${paceSeconds ~/ 60}:${(paceSeconds % 60).toString().padLeft(2, '0')}';
          }

          double distanceToNext = 0.0;
          if (i > 0) {
            double prevDistance =
                double.tryParse(
                  topRunnersData[i - 1]['total_distance_km']?.toString() ?? '0',
                ) ??
                0.0;
            distanceToNext = prevDistance - distanceKm;
          }

          String firstName = row['first_name']?.toString() ?? '';
          String lastName = row['last_name']?.toString() ?? '';
          String finalName = '$firstName $lastName'.trim();
          if (finalName.isEmpty || finalName.toLowerCase() == 'null') {
            finalName = 'YRC Koşucusu';
          }

          String rawProfileUrl = (row['profile_url'] ?? '').toString().trim();
          String finalAvatarUrl =
              (rawProfileUrl.isNotEmpty &&
                      rawProfileUrl.toLowerCase() != 'null')
                  ? rawProfileUrl
                  : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(finalName)}&background=82B1F2&color=fff';

          int? rowStravaId = int.tryParse(row['strava_id']?.toString() ?? '');
          bool isMe = (myStravaId != null && rowStravaId == myStravaId);

          if (isMe) isCurrentUserInTop30 = true;

          final runnerObj = RunnerRank(
            rank:
                realRank, // Artık i+1 değil, veritabanının verdiği gerçek sıra
            name: finalName,
            avatarUrl: finalAvatarUrl,
            distanceKm: distanceKm,
            avgPace: formattedPace,
            runsCount: runsCount,
            distanceToNext: distanceToNext,
            isCurrentUser: isMe,
          );

          fetchedRunners.add(runnerObj);
          if (isMe) myRunnerData = runnerObj;
        }

        // --- OPTİMİZASYON 2: Kullanıcı ilk 30'da yoksa, sadece onu bulup getiren ekstra ufak sorgu ---
        if (!isCurrentUserInTop30 && myStravaId != null) {
          final myData =
              await supabase
                  .from('weekly_leaderboard_ranked')
                  .select()
                  .eq('strava_id', myStravaId)
                  .maybeSingle();

          if (myData != null) {
            double distanceKm =
                double.tryParse(
                  myData['total_distance_km']?.toString() ?? '0',
                ) ??
                0.0;
            int totalSeconds =
                int.tryParse(
                  myData['total_moving_time_seconds']?.toString() ?? '0',
                ) ??
                0;
            int realRank =
                int.tryParse(myData['real_rank']?.toString() ?? '0') ?? 999;

            String formattedPace = '--:--';
            if (distanceKm > 0 && totalSeconds > 0) {
              int paceSeconds = (totalSeconds / distanceKm).round();
              formattedPace =
                  '${paceSeconds ~/ 60}:${(paceSeconds % 60).toString().padLeft(2, '0')}';
            }

            String finalAvatarUrl =
                myData['profile_url'] ??
                'https://ui-avatars.com/api/?name=Sen&background=82B1F2&color=fff';

            myRunnerData = RunnerRank(
              rank: realRank,
              name: 'Sen',
              avatarUrl: finalAvatarUrl,
              distanceKm: distanceKm,
              avgPace: formattedPace,
              runsCount:
                  int.tryParse(myData['runs_count']?.toString() ?? '0') ?? 0,
              isCurrentUser: true,
            );
            // Listeye eklemiyoruz, sadece en alttaki özel CurrentUserCard için tutuyoruz.
          }
        }

        // --- OPTİMİZASYON 3: Toplam Kulüp KM'sini ve Kişi Sayısını Ayrı Almak ---
        // Madem listeyi 30'la kısıtladık, kulübün gerçek toplam KM'sini almak için hafif bir sayım yapıyoruz

        final countResponse = await supabase
            .from('weekly_leaderboard')
            .select('strava_id')
            .count(CountOption.exact);
        int totalRealParticipants = countResponse.count;

        if (mounted) {
          setState(() {
            _runners = fetchedRunners;
            _totalParticipants =
                totalRealParticipants; // Artık listedeki eleman sayısı değil, gerçek koşucu sayısı
            _totalClubDistance =
                totalClubKm; // Şimdilik sadece ilk 30'un toplamı (İleride SQL ile çözeriz)

            // Eğer kullanıcı top 30'da değilse bile, aşağıda kartı çıksın diye listeye eklemeden onu state'e kaydediyoruz
            // Bizim UI'ımız currentUser'ı _runners içinden bulduğu için, eğer top 30'da yoksa listeye SADECE senin verini itiyoruz (görünmez olarak veya sona)
            if (!isCurrentUserInTop30 && myRunnerData != null) {
              _runners.add(myRunnerData);
            }

            _currentState =
                _runners.isEmpty
                    ? LeaderboardState.empty
                    : LeaderboardState.loaded;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _runners = [];
            _totalParticipants = 0;
            _totalClubDistance = 0.0;
            _currentState = LeaderboardState.empty;
          });
        }
      }
    } catch (e) {
      debugPrint('Leaderboard çekilirken hata: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Sıralama yüklenemedi.';
          _currentState = LeaderboardState.error;
        });
      }
    }
  }

  void _onTabChanged(LeaderboardTab tab) {
    if (_activeTab == tab) return;
    setState(() => _activeTab = tab);
    _fetchLeaderboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainBgColor,
      body: SafeArea(
        child: ResponsiveLayout(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'LİDERLİK TABLOSU',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              _buildModernSegmentedControl(),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStateBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSegmentedControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 44,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment:
                _activeTab == LeaderboardTab.totalWeekly
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutBack,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: neonBlue,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: neonBlue.withAlpha((0.4 * 255).round()),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _buildSegmentText('TÜM KOŞULAR', LeaderboardTab.totalWeekly),
              _buildSegmentText('YRC ETKİNLİKLERİ', LeaderboardTab.yrcOnly),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentText(String title, LeaderboardTab tab) {
    bool isActive = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabChanged(tab),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color:
                  isActive
                      ? mainBgColor
                      : Colors.white.withAlpha((0.6 * 255).round()),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateBody() {
    switch (_currentState) {
      case LeaderboardState.loading:
        return _buildLoadingState();
      case LeaderboardState.empty:
        return _buildEmptyState();
      case LeaderboardState.error:
        return Center(
          child: Text(
            _errorMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case LeaderboardState.loaded:
        return _buildLoadedState();
    }
  }

  Widget _buildLoadingState() {
    return ShimmerEffect(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 6,
        itemBuilder: (context, index) => _buildSkeletonCard(),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 20, height: 16, borderRadius: 4),
          const SizedBox(width: 12),
          const SkeletonBox(width: 40, height: 40, borderRadius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                SkeletonBox(width: 90, height: 10, borderRadius: 4),
              ],
            ),
          ),
          const SkeletonBox(width: 40, height: 18, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_run_outlined,
            size: 48,
            color: Colors.white.withAlpha((0.2 * 255).round()),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz Koşan Yok',
            style: TextStyle(
              color: Colors.white.withAlpha((0.5 * 255).round()),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState() {
    RunnerRank? currentUser;
    for (var r in _runners) {
      if (r.isCurrentUser) {
        currentUser = r;
        break;
      }
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: neonBlue,
          backgroundColor: cardBgColor,
          onRefresh: _fetchLeaderboardData,
          child: AnimationLimiter(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 16,
                      bottom: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_totalParticipants Koşucu',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.6 * 255).round()),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Toplam ${_totalClubDistance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.6 * 255).round()),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 100,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 400),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            // Dışarı aktardığımız RunnerCard'ı kullanıyoruz
                            child: RunnerCard(runner: _runners[index]),
                          ),
                        ),
                      ),
                      childCount: _runners.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (currentUser != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            // Dışarı aktardığımız CurrentUserCard'ı kullanıyoruz
            child: CurrentUserCard(currentUser: currentUser),
          ),
      ],
    );
  }
}
