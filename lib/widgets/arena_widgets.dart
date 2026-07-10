import 'package:flutter/material.dart';
import '../screens/arena_screen.dart'; // YRCStyle'ı kullanabilmek için import ediyoruz

// --- 1. MİKRO REKABET (DURUM) KARTI ---
class ArenaStatusCard extends StatelessWidget {
  const ArenaStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: YRCStyle.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: YRCStyle.accent.withAlpha(40)),
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
                color: YRCStyle.accent.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.radar, color: YRCStyle.accent, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "ŞU AN 4. SIRADASIN",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Podyuma çıkmak için 45 PTS daha gerekiyor. Durma!",
                    style: TextStyle(
                      color: YRCStyle.textSec,
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

// --- 2. HAFTALIK GÖREVLER (BOUNTIES) LİSTESİ ---
class ArenaBountiesList extends StatelessWidget {
  const ArenaBountiesList({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: const [
          BountyCard(
            title: "Şafak Bekçisi",
            description: "Bu hafta 3 gün sabah 08:00'den önce koşunu tamamla.",
            points: "+50 PTS",
            icon: Icons.wb_twilight_rounded,
          ),
          BountyCard(
            title: "Yokuş Aslanı",
            description: "Tek bir aktivitede +200m irtifa kazanımına ulaş.",
            points: "+100 PTS",
            icon: Icons.terrain_rounded,
          ),
          BountyCard(
            title: "Uzun Yol",
            description: "Hafta bitmeden tek seferde 10K barajını aş.",
            points: "+75 PTS",
            icon: Icons.route_rounded,
          ),
        ],
      ),
    );
  }
}

// --- 3. BİREYSEL GÖREV KARTI TASARIMI ---
class BountyCard extends StatelessWidget {
  final String title;
  final String description;
  final String points;
  final IconData icon;

  const BountyCard({
    super.key,
    required this.title,
    required this.description,
    required this.points,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: YRCStyle.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15)),
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
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: YRCStyle.accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: YRCStyle.accent.withAlpha(50)),
                ),
                child: Text(
                  points,
                  style: const TextStyle(
                    color: YRCStyle.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
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
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: YRCStyle.textSec,
              fontSize: 12,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
