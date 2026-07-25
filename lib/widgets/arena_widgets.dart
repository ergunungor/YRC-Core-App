import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; // YENİ: Tek Doğruluk Kaynağımız
import '../screens/arena_screen.dart';

// --- 1. DİNAMİK MİKRO REKABET (DURUM) KARTI ---
class ArenaStatusCard extends StatelessWidget {
  final int currentRank;
  final int pointsToNext;
  final String targetName;
  final bool hasRunThisWeek;

  const ArenaStatusCard({
    super.key,
    required this.currentRank,
    required this.pointsToNext,
    required this.targetName,
    required this.hasRunThisWeek,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Durum: Hiç koşmamışsa motive et
    if (!hasRunThisWeek) {
      return _buildCardWrapper(
        icon: Icons.directions_run_rounded,
        title: "ARENAYA ÇIKMA VAKTİ",
        subtitle:
            "Bu hafta henüz YRC Skoru üretmedin. İlk koşunu kaydet ve sıralamaya gir!",
      );
    }

    // 2. Durum: Zaten 1. sıradaysa (Kral)
    if (currentRank <= 1) {
      return _buildCardWrapper(
        icon: Icons.workspace_premium_rounded,
        title: "ZİRVEDESİN!",
        subtitle:
            "Şu an lider sensin. En yakın rakibinle arayı açmak için koşmaya devam et.",
        isKing: true,
      );
    }

    // 3. Durum: Normal rekabet (Birini geçmeye çalışıyor)
    return _buildCardWrapper(
      icon: Icons.radar,
      title: "ŞU AN $currentRank. SIRADASIN",
      subtitle:
          "Bir üstündeki $targetName'i geçmek için $pointsToNext PTS daha gerekiyor. Durma!",
    );
  }

  Widget _buildCardWrapper({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isKing = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.yrcCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.yrcAccent.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(100),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.yrcAccent.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.yrcAccent, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isKing ? AppColors.yrcAccent : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.yrcTextSec,
                      fontSize: 13,
                      height: 1.4,
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

// --- 2. DİNAMİK HAFTALIK GÖREVLER (BOUNTIES) LİSTESİ ---
class ArenaBountiesList extends StatelessWidget {
  final List<BountyItem> bounties;

  const ArenaBountiesList({super.key, required this.bounties});

  @override
  Widget build(BuildContext context) {
    if (bounties.isEmpty) {
      return const SizedBox(height: 0);
    }

    return SizedBox(
      height: 220, // İlerleme çubuğu sığsın diye boyutu bir tık büyüttük
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children:
            bounties.map((b) {
              return BountyCard(
                title: b.title,
                description: b.description,
                points: "+${b.rewardXp} XP",
                icon: _iconForBounty(b.title),
                progress: b.progress,
              );
            }).toList(),
      ),
    );
  }

  IconData _iconForBounty(String title) {
    if (title.contains("İstikrar")) return Icons.calendar_month_rounded;
    if (title.contains("İrtifa")) return Icons.terrain_rounded;
    if (title.contains("KM")) return Icons.route_rounded;
    return Icons.emoji_events_rounded;
  }
}

// --- 3. İLERLEME ÇUBUKLU (PROGRESS BAR) GÖREV KARTI TASARIMI ---
class BountyCard extends StatelessWidget {
  final String title;
  final String description;
  final String points;
  final IconData icon;
  final double progress; // 0.0 ile 1.0 arası değer

  const BountyCard({
    super.key,
    required this.title,
    required this.description,
    required this.points,
    required this.icon,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // İlerlemeyi güvenli (0.0 - 1.0 arası) limite çekiyoruz
    final safeProgress = progress.clamp(0.0, 1.0);
    final isCompleted = safeProgress == 1.0;
    final percentage = (safeProgress * 100).toInt();

    return Container(
      width: 240,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.yrcCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isCompleted
                  ? AppColors.yrcAccent.withAlpha(100)
                  : Colors.white.withAlpha(15),
          width: isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      isCompleted
                          ? AppColors.yrcAccent
                          : Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : icon,
                  color: isCompleted ? Colors.black : Colors.white,
                  size: 20,
                ),
              ),
              Row(
                children: [
                  // Yüzde Metni
                  Text(
                    "$percentage%",
                    style: TextStyle(
                      color: isCompleted ? AppColors.yrcAccent : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Puan (Eğer tamamlandıysa TAMAM yazacak)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.yrcAccent.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.yrcAccent.withAlpha(50),
                      ),
                    ),
                    child: Text(
                      isCompleted ? "TAMAM" : points,
                      style: const TextStyle(
                        color: AppColors.yrcAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.yrcTextSec,
              fontSize: 12,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // --- YENİ: İLERLEME ÇUBUĞU (PROGRESS BAR) ---
          Stack(
            children: [
              // Arka plan (Sönük çizgi)
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Doluluk Çizgisi (Neon Volt)
              FractionallySizedBox(
                widthFactor: safeProgress, // Doluluk oranını ayarlıyor
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.yrcAccent,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow:
                        isCompleted
                            ? AppColors.yrcNeonGlow
                            : [], // Tamamlanınca parla
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
