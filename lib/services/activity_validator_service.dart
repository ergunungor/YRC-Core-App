import 'dart:math' as math;

class ActivityValidatorService {
  // ==========================================
  // 1. SAAT DOĞRULAMA (TIME VALIDATION)
  // ==========================================

  /// Gelen Strava aktivitesinin başlangıç zamanı, etkinliğin saatiyle uyuşuyor mu?
  bool validateTime({
    required String activityStartDateIso,
    required String eventDateIso,
    int beforeToleranceMinutes = 30,
    int afterToleranceMinutes = 45,
  }) {
    try {
      final DateTime activityTime =
          DateTime.parse(activityStartDateIso).toUtc();
      final DateTime eventTime = DateTime.parse(eventDateIso).toUtc();

      final DateTime minAllowedTime = eventTime.subtract(
        Duration(minutes: beforeToleranceMinutes),
      );
      final DateTime maxAllowedTime = eventTime.add(
        Duration(minutes: afterToleranceMinutes),
      );

      final bool isAfterMin =
          activityTime.isAfter(minAllowedTime) ||
          activityTime.isAtSameMomentAs(minAllowedTime);
      final bool isBeforeMax =
          activityTime.isBefore(maxAllowedTime) ||
          activityTime.isAtSameMomentAs(maxAllowedTime);

      return isAfterMin && isBeforeMax;
    } catch (e) {
      return false; // Hata durumunda doğrulamayı reddet
    }
  }

  // ==========================================
  // 2. KONUM DOĞRULAMA (LOCATION VALIDATION)
  // ==========================================

  /// Strava aktivitesinin başlangıç konumu, etkinlik konumuna yakın mı?
  ///
  /// [toleranceMeters]: Kabul edilebilir maksimum uzaklık (Varsayılan: 500 metre)
  bool validateLocation({
    required double activityLat,
    required double activityLng,
    required double eventLat,
    required double eventLng,
    double toleranceMeters = 500.0,
  }) {
    try {
      final double distance = _calculateDistance(
        activityLat,
        activityLng,
        eventLat,
        eventLng,
      );

      return distance <= toleranceMeters;
    } catch (e) {
      return false; // Hata durumunda doğrulamayı reddet
    }
  }

  // --- YARDIMCI MATEMATİK FONKSİYONLARI (HAVERSINE) ---

  /// İki koordinat arasındaki mesafeyi metre cinsinden hesaplar
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Dünya'nın yarıçapı (metre)

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
