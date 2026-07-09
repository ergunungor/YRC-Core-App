import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/runner_rank.dart'; // Modelimizi içeri alıyoruz

// Ortak renkleri burada tanımlıyoruz
const Color _neonBlue = Color(0xFF82B1F2);
const Color _cardBgColor = Color(0xFF132035);
const Color _goldColor = Color(0xFFFFD700);
const Color _silverColor = Color(0xFFE0E0E0);
const Color _bronzeColor = Color(0xFFCD7F32);

class RunnerCard extends StatelessWidget {
  final RunnerRank runner;

  const RunnerCard({super.key, required this.runner});

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    IconData? medalIcon;
    if (runner.rank == 1) {
      rankColor = _goldColor;
      medalIcon = Icons.emoji_events_rounded;
    } else if (runner.rank == 2) {
      rankColor = _silverColor;
      medalIcon = Icons.military_tech_rounded;
    } else if (runner.rank == 3) {
      rankColor = _bronzeColor;
      medalIcon = Icons.military_tech_rounded;
    } else {
      rankColor = Colors.transparent;
      medalIcon = null;
    }

    bool isTop3 = runner.isTop3;

    BoxDecoration cardDecoration;
    if (runner.isCurrentUser) {
      cardDecoration = BoxDecoration(
        color: _neonBlue.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _neonBlue.withAlpha((0.4 * 255).round()),
          width: 1.0,
        ),
      );
    } else if (isTop3) {
      cardDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [rankColor.withAlpha((0.14 * 255).round()), _cardBgColor],
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
        color: _cardBgColor,
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
            ],
          ),
        ],
      ),
    );
  }
}

class CurrentUserCard extends StatelessWidget {
  final RunnerRank currentUser;

  const CurrentUserCard({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _neonBlue.withAlpha((0.15 * 255).round()),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _neonBlue.withAlpha((0.5 * 255).round()),
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
