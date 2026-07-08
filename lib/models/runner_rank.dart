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
