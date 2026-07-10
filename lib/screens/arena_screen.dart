import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wrapped_share_screen.dart';

class YRCStyle {
  static const Color background = Color(0xFF0B101A);
  static const Color cardBg = Color(0xFF161F33);
  static const Color accent = Color(0xFFD4FF00); // Neon Volt
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textSec = Color(0xFF94A3B8);

  static final List<BoxShadow> neonGlow = [
    BoxShadow(
      color: accent.withAlpha(77),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

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

class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  List<ScoreRank> _currentPodium = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _fetchPerformanceData();
  }

  Future<void> _fetchPerformanceData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Doğrudan SQL View'a bağlanıp haftanın en yüksek YRC skorlarını alıyoruz
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

          fetched.add(
            ScoreRank(
              rank: i + 1,
              name: firstName,
              score: int.tryParse(row['yrc_score']?.toString() ?? '0') ?? 0,
              avatarUrl:
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
        }
        return;
      }
    } catch (e) {
      debugPrint('Supabase YRC Skor verisi çekilemedi: $e');
    }

    // --- FALLBACK / DEMO DATA ---
    // Eğer o hafta hiç veri yoksa (veya internet koptuysa) şov devam etsin diye
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _currentPodium = [
          ScoreRank(
            rank: 1,
            name: "Ergün",
            score: 850,
            avatarUrl: "https://i.pravatar.cc/150?u=1",
            isKing: true,
          ),
          ScoreRank(
            rank: 2,
            name: "Zeynep",
            score: 710,
            avatarUrl: "https://i.pravatar.cc/150?u=2",
          ),
          ScoreRank(
            rank: 3,
            name: "Mehmet",
            score: 640,
            avatarUrl: "https://i.pravatar.cc/150?u=3",
          ),
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YRCStyle.background,
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
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
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
                  color: YRCStyle.accent,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "HAFTANIN\nPARLAYANLARI",
                style: TextStyle(
                  color: YRCStyle.textMain,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(26)),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.ios_share_rounded,
                color: YRCStyle.textMain,
              ),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WrappedShareScreen(),
                    ),
                  ),
              splashRadius: 24,
            ),
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
            child: CircularProgressIndicator(color: YRCStyle.accent),
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
              "Bu hafta henüz YRC skoru oluşmadı.",
              style: TextStyle(
                color: YRCStyle.textSec,
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
                    color: rankUser.isKing ? YRCStyle.accent : YRCStyle.cardBg,
                    width: rankUser.isKing ? 4 : 2,
                  ),
                  boxShadow: rankUser.isKing ? YRCStyle.neonGlow : [],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: rankUser.avatarUrl,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(color: YRCStyle.cardBg),
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
                      color: YRCStyle.cardBg,
                      shape: BoxShape.circle,
                      boxShadow: YRCStyle.neonGlow,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: YRCStyle.accent,
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
                    color: rankUser.isKing ? YRCStyle.accent : YRCStyle.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: YRCStyle.background, width: 3),
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
              color: rankUser.isKing ? YRCStyle.textMain : YRCStyle.textSec,
              fontWeight: FontWeight.bold,
              fontSize: rankUser.isKing ? 18 : 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "${rankUser.score} PTS",
            style: TextStyle(
              color: YRCStyle.accent,
              fontWeight: FontWeight.w900,
              fontSize: rankUser.isKing ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
