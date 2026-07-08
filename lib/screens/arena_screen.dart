import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'wrapped_share_screen.dart';
import 'challenge_accepted_screen.dart';

class YRCStyle {
  static const Color background = Color(0xFF0B101A);
  static const Color cardBg = Color(0xFF161F33);
  static const Color accent = Color(0xFFD4FF00);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textSec = Color(0xFF94A3B8);

  static final List<BoxShadow> neonGlow = [
    BoxShadow(
      color: accent.withOpacity(0.3),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];
}

class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  int _selectedDistanceIndex = 3; // Varsayılan: 5K
  final List<String> _distances = ["400m", "1 Mile", "3K", "5K", "10K"];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YRCStyle.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(),
            _buildDistanceSelector(),
            _buildPodium(),
            _buildSectionTitle("SON MEYDAN OKUMALAR"),
            _buildChallengeGrid(),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
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
                "Haftanın\nKralları",
                style: TextStyle(
                  color: YRCStyle.textMain,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.ios_share_rounded,
                color: YRCStyle.textMain,
              ),
              onPressed: () {
                // Wrapped Ekranına Geçiş BAĞLANTISI
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WrappedShareScreen(),
                  ),
                );
              },
              splashRadius: 24,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildDistanceSelector() => SliverToBoxAdapter(
    child: SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _distances.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedDistanceIndex == index;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedDistanceIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isSelected ? YRCStyle.accent : YRCStyle.cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isSelected ? YRCStyle.neonGlow : [],
                border: Border.all(
                  color: isSelected ? YRCStyle.accent : Colors.transparent,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _distances[index],
                style: TextStyle(
                  color: isSelected ? Colors.black : YRCStyle.textSec,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: isSelected ? 0.5 : 0,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _buildPodium() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 24, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _podiumAvatar(
              rank: 2,
              name: "Zeynep",
              time: "19:42",
              size: 65,
              heightOffset: 20,
            ),
          ),
          Expanded(
            child: _podiumAvatar(
              rank: 1,
              name: "Ergün",
              time: "18:30",
              size: 100,
              heightOffset: 40,
              isKing: true,
            ),
          ),
          Expanded(
            child: _podiumAvatar(
              rank: 3,
              name: "Mehmet",
              time: "20:15",
              size: 65,
              heightOffset: 0,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _podiumAvatar({
    required int rank,
    required String name,
    required String time,
    required double size,
    required double heightOffset,
    bool isKing = false,
  }) {
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
                    color: isKing ? YRCStyle.accent : YRCStyle.cardBg,
                    width: isKing ? 4 : 2,
                  ),
                  boxShadow: isKing ? YRCStyle.neonGlow : [],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: 'https://i.pravatar.cc/150?u=$rank',
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(color: YRCStyle.cardBg),
                    errorWidget:
                        (context, url, error) =>
                            const Icon(Icons.error, color: Colors.white24),
                  ),
                ),
              ),
              if (isKing)
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
                    color: isKing ? YRCStyle.accent : YRCStyle.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: YRCStyle.background, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$rank",
                    style: TextStyle(
                      color: isKing ? Colors.black : Colors.white,
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
            name,
            style: TextStyle(
              color: isKing ? YRCStyle.textMain : YRCStyle.textSec,
              fontWeight: FontWeight.bold,
              fontSize: isKing ? 18 : 14,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: YRCStyle.accent,
              fontWeight: FontWeight.w900,
              fontSize: isKing ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Text(
        title,
        style: const TextStyle(
          color: YRCStyle.textSec,
          letterSpacing: 2,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  Widget _buildChallengeGrid() => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, i) => _ChallengeCard(index: i),
        childCount: 4,
      ),
    ),
  );
}

class _ChallengeCard extends StatelessWidget {
  final int index;
  const _ChallengeCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final imgUrl =
        index % 2 == 0
            ? 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?q=80&w=400'
            : 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?q=80&w=400';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Arka Plan Fotoğrafı - Optimize Edildi
            CachedNetworkImage(
              imageUrl: imgUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: YRCStyle.cardBg),
              errorWidget:
                  (context, url, error) =>
                      const Icon(Icons.error, color: Colors.white24),
            ),

            // Okunabilirlik için karanlık degrade eklendi
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                  stops: [0.4, 0.7, 1.0],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: YRCStyle.accent, width: 2),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: 'https://i.pravatar.cc/100?u=$index',
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) =>
                                    Container(color: YRCStyle.cardBg),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Ahmet Can",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "4:45 pace / 5K",
                    style: TextStyle(
                      color: YRCStyle.textSec,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        // Meydan Okuma Ekranına Geçiş BAĞLANTISI (Hatası düzeltildi)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const ChallengeAcceptedScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: YRCStyle.accent,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "BUNU GEÇ",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
