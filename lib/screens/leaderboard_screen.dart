import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import '../widgets/shimmer_loading.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

enum LeaderboardState { loading, loaded, empty, error }

enum LeaderboardTab { totalWeekly, yrcOnly }

class RunnerRank {
  final int rank;
  final String name;
  final String avatarUrl;
  final double distanceKm;
  final String avgPace;
  final int runsCount;
  final int rankChange;
  final double distanceToNext;
  final bool isCurrentUser;

  RunnerRank({
    required this.rank,
    required this.name,
    required this.avatarUrl,
    required this.distanceKm,
    required this.avgPace,
    required this.runsCount,
    this.rankChange = 0,
    this.distanceToNext = 0.0,
    this.isCurrentUser = false,
  });

  bool get isTop3 => rank <= 3;
}

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

  final Color goldColor = const Color(0xFFFFD700);
  final Color silverColor = const Color(0xFFE0E0E0);
  final Color bronzeColor = const Color(0xFFCD7F32);

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

      // 2. Sadece bu haftanın Pazartesisinden itibaren olan verileri View üzerinden çekiyoruz
      if (_activeTab == LeaderboardTab.totalWeekly) {
        final List<dynamic> data =
            await supabase.from('weekly_leaderboard').select();

        List<RunnerRank> fetchedRunners = [];
        double totalClubKm = 0.0;

        for (int i = 0; i < data.length; i++) {
          final row = data[i];

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

          totalClubKm += distanceKm;

          // Hız (Pace) Hesaplama
          String formattedPace = '--:--';
          if (distanceKm > 0 && totalSeconds > 0) {
            int paceSeconds = (totalSeconds / distanceKm).round();
            int minutes = paceSeconds ~/ 60;
            int seconds = paceSeconds % 60;
            formattedPace = '$minutes:${seconds.toString().padLeft(2, '0')}';
          }

          // Önündeki koşucuyla mesafe farkı
          double distanceToNext = 0.0;
          if (i > 0) {
            double prevDistance =
                double.tryParse(
                  data[i - 1]['total_distance_km']?.toString() ?? '0',
                ) ??
                0.0;
            distanceToNext = prevDistance - distanceKm;
          }

          // İsim ve Fotoğraf Bilgilerini Ayıkla (Null kelimelerini temizler)
          String firstName = row['first_name']?.toString() ?? '';
          String lastName = row['last_name']?.toString() ?? '';
          String finalName = '$firstName $lastName'.trim();
          if (finalName.isEmpty || finalName.toLowerCase() == 'null') {
            finalName = 'YRC Koşucusu';
          }

          String rawProfileUrl = (row['profile_url'] ?? '').toString().trim();
          String profileUrl = '';
          if (rawProfileUrl.isNotEmpty &&
              rawProfileUrl.toLowerCase() != 'null') {
            profileUrl = rawProfileUrl;
          }

          String finalAvatarUrl =
              profileUrl.isNotEmpty
                  ? profileUrl
                  : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(finalName)}&background=82B1F2&color=fff';

          int? rowStravaId = int.tryParse(row['strava_id']?.toString() ?? '');

          fetchedRunners.add(
            RunnerRank(
              rank: i + 1,
              name: finalName,
              avatarUrl: finalAvatarUrl,
              distanceKm: distanceKm,
              avgPace: formattedPace,
              runsCount: runsCount,
              distanceToNext: distanceToNext,
              isCurrentUser: myStravaId != null && rowStravaId == myStravaId,
            ),
          );
        }

        if (mounted) {
          setState(() {
            _runners = fetchedRunners;
            _totalParticipants = _runners.length;
            _totalClubDistance = totalClubKm;
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
          // <-- Responsive kısıtlayıcı burada
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
    // Gerçek kartların yerini tutacak 6 tane iskelet kart üretiyoruz.
    // 6 sayısı rastgele değil: ekranda genelde bu kadar kart sığıyor,
    // gerçek veriden az önce göründüğü boşluğu doğru şekilde kaplıyor.
    return ShimmerEffect(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 6,
        itemBuilder: (context, index) => _buildSkeletonCard(),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    // DİKKAT: Bu kutuların boyutları _buildRunnerCard'daki gerçek
    // elemanlarla (rank, avatar, isim, mesafe) kabaca eşleşiyor.
    // Amaç: iskelet kaybolup gerçek veri gelince sayfa "zıplamasın".
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 20, height: 16, borderRadius: 4), // rank
          const SizedBox(width: 12),
          const SkeletonBox(width: 40, height: 40, borderRadius: 20), // avatar
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 14, borderRadius: 4), // isim
                SizedBox(height: 8),
                SkeletonBox(
                  width: 90,
                  height: 10,
                  borderRadius: 4,
                ), // koşu/pace
              ],
            ),
          ),
          const SkeletonBox(width: 40, height: 18, borderRadius: 4), // mesafe
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
            // <-- Animasyon sınırı
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
                            child: _buildRunnerCard(_runners[index]),
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
            child: _buildYourPositionCard(currentUser),
          ),
      ],
    );
  }

  Widget _buildRunnerCard(RunnerRank runner) {
    // 1. ADIM: Sıralamaya göre renk ve madalya ikonunu belirliyoruz
    Color rankColor;
    IconData? medalIcon;
    if (runner.rank == 1) {
      rankColor = goldColor;
      medalIcon = Icons.emoji_events_rounded;
    } else if (runner.rank == 2) {
      rankColor = silverColor;
      medalIcon = Icons.military_tech_rounded;
    } else if (runner.rank == 3) {
      rankColor = bronzeColor;
      medalIcon = Icons.military_tech_rounded;
    } else {
      rankColor = Colors.transparent;
      medalIcon = null;
    }

    bool isTop3 = runner.isTop3;

    // 2. ADIM: Kart arka planını duruma göre seçiyoruz.
    // Neden ayrı bir BoxDecoration değişkeni? Çünkü hem "sen"i (currentUser)
    // hem top3'ü hem de normal satırları aynı Container'da yönetmemiz lazım,
    // if-else'i widget ağacının içine gömmek yerine önce karar veriyoruz.
    BoxDecoration cardDecoration;
    if (runner.isCurrentUser) {
      cardDecoration = BoxDecoration(
        color: neonBlue.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: neonBlue.withAlpha((0.4 * 255).round()),
          width: 1.0,
        ),
      );
    } else if (isTop3) {
      cardDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [rankColor.withAlpha((0.14 * 255).round()), cardBgColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rankColor.withAlpha((0.6 * 255).round()),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: rankColor.withAlpha((0.18 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else {
      cardDecoration = BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha((0.03 * 255).round()),
          width: 1.0,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: cardDecoration,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Center(
              child:
                  medalIcon != null
                      ? Icon(medalIcon, color: rankColor, size: 22)
                      : Text(
                        '${runner.rank}',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.4 * 255).round()),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
            ),
          ),
          const SizedBox(width: 12),

          // 3. ADIM: Avatarın etrafına top3 için renkli bir halka (ring) koyuyoruz.
          // Mantık: CircleAvatar'ı bir Container'a sarıp, o Container'a
          // "shape: BoxShape.circle" + "border" veriyoruz. Container avatardan
          // biraz büyük olduğu için border, avatarın dışında bir çember gibi görünür.
          Container(
            padding: EdgeInsets.all(isTop3 ? 2 : 0),
            decoration:
                isTop3
                    ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: rankColor, width: 2),
                    )
                    : null,
            child: CircleAvatar(
              radius: isTop3 ? 21 : 20,
              backgroundColor: Colors.transparent,
              backgroundImage: NetworkImage(runner.avatarUrl),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        runner.isCurrentUser ? 'Sen' : runner.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (runner.rankChange != 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          runner.rankChange > 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color:
                              runner.rankChange > 0
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFF87171),
                          size: 14,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '• ${runner.runsCount} Koşu   • ${runner.avgPace}/km',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.5 * 255).round()),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    runner.distanceKm.toStringAsFixed(1),
                    style: TextStyle(
                      color: isTop3 ? rankColor : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'km',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (runner.distanceToNext > 0 && !runner.isCurrentUser)
                Text(
                  '-${runner.distanceToNext.toStringAsFixed(1)} km',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.5 * 255).round()),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYourPositionCard(RunnerRank currentUser) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: neonBlue.withAlpha((0.15 * 255).round()),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: neonBlue.withAlpha((0.5 * 255).round()),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Center(
                  child: Text(
                    '${currentUser.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.transparent,
                backgroundImage: NetworkImage(currentUser.avatarUrl),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Senin Sıralaman',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currentUser.distanceKm.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'km',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  const ResponsiveLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500), // Max 500px genişlik
        child: child,
      ),
    );
  }
}
