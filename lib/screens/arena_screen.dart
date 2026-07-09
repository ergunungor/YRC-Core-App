import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

import 'wrapped_share_screen.dart';
import 'challenge_accepted_screen.dart';

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

// PR (Personal Record) Modeli
class PRRank {
  final int rank;
  final String name;
  final String time; // Örn: 18:30
  final String avatarUrl;
  final bool isKing;

  PRRank({
    required this.rank,
    required this.name,
    required this.time,
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
  final ValueNotifier<int> _selectedDistanceIndex = ValueNotifier<int>(
    3,
  ); // Varsayılan: 5K
  final List<String> _distances = ["400m", "1 Mil", "3K", "5K", "10K"];

  List<PRRank> _currentPodium = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _fetchPRDataForCategory(_distances[3]); // Ekrana girince 5K verisini çek
  }

  @override
  void dispose() {
    _selectedDistanceIndex.dispose();
    super.dispose();
  }

  // --- SUPABASE VERİ ÇEKİMİ (PR'lara Göre) ---
  Future<void> _fetchPRDataForCategory(String category) async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final List<dynamic> response = await supabase
          .from('club_prs')
          .select() // 'users(...)' KALDIRILDI, direkt view içinden okuyoruz
          .eq('distance_type', category)
          .order('best_time_seconds', ascending: true)
          .limit(3);

      if (response.isNotEmpty) {
        List<PRRank> fetched = [];
        for (int i = 0; i < response.length; i++) {
          final row = response[i];

          // YENİ MANTIK: Veriler artık row'un kendi içinde!
          String firstName = row['first_name']?.toString() ?? 'Koşucu';

          fetched.add(
            PRRank(
              rank: i + 1,
              name: firstName,
              time: row['best_time_string'] ?? '--:--',
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
      debugPrint('Supabase PR verisi çekilemedi: $e');
    }

    // --- DEMO / FALLBACK MODU (Tablo yoksa veya boşsa demo data basar) ---
    // Sprint Demo'da şov yapabilmen için hata anında sahte kralları gösteriyoruz.
    if (mounted) {
      await Future.delayed(
        const Duration(milliseconds: 400),
      ); // Ufak bir yükleme animasyonu hissi
      setState(() {
        if (category == "5K") {
          _currentPodium = [
            PRRank(
              rank: 1,
              name: "Ergün",
              time: "18:30",
              avatarUrl: "https://i.pravatar.cc/150?u=1",
              isKing: true,
            ),
            PRRank(
              rank: 2,
              name: "Zeynep",
              time: "19:42",
              avatarUrl: "https://i.pravatar.cc/150?u=2",
            ),
            PRRank(
              rank: 3,
              name: "Mehmet",
              time: "20:15",
              avatarUrl: "https://i.pravatar.cc/150?u=3",
            ),
          ];
        } else if (category == "10K") {
          _currentPodium = [
            PRRank(
              rank: 1,
              name: "Ahmet",
              time: "38:45",
              avatarUrl: "https://i.pravatar.cc/150?u=4",
              isKing: true,
            ),
            PRRank(
              rank: 2,
              name: "Ergün",
              time: "41:10",
              avatarUrl: "https://i.pravatar.cc/150?u=1",
            ),
            PRRank(
              rank: 3,
              name: "Süleyman",
              time: "42:00",
              avatarUrl: "https://i.pravatar.cc/150?u=5",
            ),
          ];
        } else {
          _currentPodium = [
            PRRank(
              rank: 1,
              name: "Polat",
              time: "1:05",
              avatarUrl: "https://i.pravatar.cc/150?u=6",
              isKing: true,
            ),
          ];
        }
        _isLoading = false;
      });
    }
  }

  // --- DİNAMİK MEYDAN OKUMA (CUSTOM CHALLENGE) MENÜSÜ ---
  void _showAddChallengeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: YRCStyle.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        // BottomSheet içi state yönetimi için StatefulBuilder şart
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return _CustomChallengeBuilder(
              onChallengeCreated: (double km, String pace) {
                Navigator.pop(context); // Menüyü kapat
                HapticFeedback.heavyImpact();
                // Burada veritabanına meydan okuma kaydedilebilir
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "$km KM ve $pace Pace hedeflik meydan okuma gönderildi!",
                    ),
                    backgroundColor: YRCStyle.accent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            );
          },
        );
      },
    );
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
                _buildDistanceSelector(),
                _buildPodium(),
                _buildSectionTitle("AKTİF MEYDAN OKUMALAR"),
                _buildChallengesList(),
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
                "Tüm Zamanların\nKralları",
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

  Widget _buildDistanceSelector() => SliverToBoxAdapter(
    child: SizedBox(
      height: 48,
      child: ValueListenableBuilder<int>(
        valueListenable: _selectedDistanceIndex,
        builder: (context, selectedIndex, child) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _distances.length,
            itemBuilder: (context, index) {
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  if (isSelected) return; // Zaten seçiliyse tekrar çekme
                  HapticFeedback.lightImpact();
                  _selectedDistanceIndex.value = index;
                  _fetchPRDataForCategory(
                    _distances[index],
                  ); // Yeni kategoriyi çek
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
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: isSelected ? 0.5 : 0,
                    ),
                  ),
                ),
              );
            },
          );
        },
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
              "Bu kategoride henüz rekor yok.",
              style: TextStyle(
                color: YRCStyle.textSec,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    PRRank? king = _currentPodium.isNotEmpty ? _currentPodium[0] : null;
    PRRank? second = _currentPodium.length > 1 ? _currentPodium[1] : null;
    PRRank? third = _currentPodium.length > 2 ? _currentPodium[2] : null;

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

  Widget _podiumAvatar(PRRank pr, double size, double heightOffset) {
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
                    color: pr.isKing ? YRCStyle.accent : YRCStyle.cardBg,
                    width: pr.isKing ? 4 : 2,
                  ),
                  boxShadow: pr.isKing ? YRCStyle.neonGlow : [],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: pr.avatarUrl,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(color: YRCStyle.cardBg),
                    errorWidget:
                        (context, url, error) =>
                            const Icon(Icons.error, color: Colors.white24),
                  ),
                ),
              ),
              if (pr.isKing)
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
                    color: pr.isKing ? YRCStyle.accent : YRCStyle.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: YRCStyle.background, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${pr.rank}",
                    style: TextStyle(
                      color: pr.isKing ? Colors.black : Colors.white,
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
            pr.name,
            style: TextStyle(
              color: pr.isKing ? YRCStyle.textMain : YRCStyle.textSec,
              fontWeight: FontWeight.bold,
              fontSize: pr.isKing ? 18 : 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            pr.time,
            style: TextStyle(
              color: YRCStyle.accent,
              fontWeight: FontWeight.w900,
              fontSize: pr.isKing ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: YRCStyle.textSec,
              letterSpacing: 2,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showAddChallengeSheet();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: YRCStyle.accent.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: YRCStyle.accent.withAlpha(77)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.add, color: YRCStyle.accent, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "YENİ",
                    style: TextStyle(
                      color: YRCStyle.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildChallengesList() => SliverToBoxAdapter(
    child: SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3, // Şimdilik demo için 3
        itemBuilder:
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: 220, child: _ChallengeCard(index: index)),
            ),
      ),
    ),
  );
}

// --- YENİ: KİŞİSELLEŞTİRİLMİŞ MEYDAN OKUMA WIDGETI ---
// Kullanıcının slider / butonlarla kendi değerlerini seçebilmesi için ayrılmış StatefulBuilder
class _CustomChallengeBuilder extends StatefulWidget {
  final Function(double km, String pace) onChallengeCreated;
  const _CustomChallengeBuilder({required this.onChallengeCreated});

  @override
  State<_CustomChallengeBuilder> createState() =>
      _CustomChallengeBuilderState();
}

class _CustomChallengeBuilderState extends State<_CustomChallengeBuilder> {
  double _targetKm = 5.0;
  int _paceMinutes = 4;
  int _paceSeconds = 30;

  void _adjustKm(double amount) {
    setState(() {
      _targetKm = (_targetKm + amount).clamp(1.0, 42.2);
    });
    HapticFeedback.selectionClick();
  }

  void _adjustPace(int secondsAmount) {
    setState(() {
      int totalSeconds = (_paceMinutes * 60) + _paceSeconds + secondsAmount;
      totalSeconds = totalSeconds.clamp(180, 720); // 3:00 - 12:00 limit
      _paceMinutes = totalSeconds ~/ 60;
      _paceSeconds = totalSeconds % 60;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    String formattedPace =
        '$_paceMinutes:${_paceSeconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 40),
      height: MediaQuery.of(context).size.height * 0.70,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "MEYDAN OKU",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const Text(
            "Kulüp liderlerini terletmeye hazır mısın?",
            style: TextStyle(color: YRCStyle.textSec, fontSize: 14),
          ),
          const SizedBox(height: 40),

          // MESAFE SEÇİCİ
          const Text(
            "MESAFE HEDEFİ",
            style: TextStyle(
              color: YRCStyle.accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: YRCStyle.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white54,
                    size: 36,
                  ),
                  onPressed: () => _adjustKm(-0.5),
                ),
                Text(
                  "${_targetKm.toStringAsFixed(1)} KM",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white54,
                    size: 36,
                  ),
                  onPressed: () => _adjustKm(0.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // PACE SEÇİCİ
          const Text(
            "PACE HEDEFİ",
            style: TextStyle(
              color: YRCStyle.accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: YRCStyle.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white54,
                    size: 36,
                  ),
                  onPressed: () => _adjustPace(-5),
                ),
                Text(
                  "$formattedPace",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white54,
                    size: 36,
                  ),
                  onPressed: () => _adjustPace(5),
                ),
              ],
            ),
          ),

          const Spacer(),

          // GÖNDER BUTONU
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed:
                  () => widget.onChallengeCreated(_targetKm, formattedPace),
              style: ElevatedButton.styleFrom(
                backgroundColor: YRCStyle.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "KULÜBE MEYDAN OKU",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Meydan Okuma Kartı
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imgUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: YRCStyle.cardBg),
              errorWidget:
                  (context, url, error) =>
                      const Icon(Icons.error, color: Colors.white24),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                  stops: [0.3, 0.7, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(30)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: YRCStyle.accent,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      "2 Gün",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
                          "YRC Aslanı",
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
                  Text(
                    "${(index + 1) * 5}K Hız Testi",
                    style: const TextStyle(
                      color: YRCStyle.textSec,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    "Hedef: 4:${30 + (index * 15)} pace",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
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
