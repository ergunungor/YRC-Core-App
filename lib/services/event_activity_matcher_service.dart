import 'activity_validator_service.dart';

/// Birden fazla Event ile birden fazla Strava Aktivitesi arasında
/// "en yakın saat + geçerli konum" kuralına göre 1-e-1 eşleştirme yapan servis.
///
/// KURALLAR:
/// - Bir aktivite SADECE bir evente atanabilir.
/// - Bir event SADECE bir aktivite ile eşleşebilir.
/// - "Son aktiviteyi getir" mantığı YOKTUR, tüm günün aktiviteleri değerlendirilir.
class EventActivityMatcherService {
  final ActivityValidatorService _validator;

  EventActivityMatcherService({ActivityValidatorService? validator})
    : _validator = validator ?? ActivityValidatorService();

  /// [events]: Her biri {id, date (ISO String), lat, lng} içeren liste.
  /// [activities]: Her biri {activity_id, start_date (ISO String), start_lat, start_lng} içeren liste.
  ///
  /// Dönüş: eventId -> activityId (eşleşme yoksa değer null, yani "missed").
  Map<String, dynamic> matchEventsToActivities({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> activities,
  }) {
    // 1. AŞAMA: Her event için, saat + konum filtresinden geçen adayları bul.
    final Map<String, List<_Candidate>> candidatesByEvent = {};

    for (final event in events) {
      final String eventId = event['id'].toString();
      final String eventDateIso = event['date'];
      final double eventLat = _toDouble(event['lat']);
      final double eventLng = _toDouble(event['lng']);

      final List<_Candidate> candidates = [];

      for (final activity in activities) {
        final String activityStartDateIso = activity['start_date'];

        final bool isTimeValid = _validator.validateTime(
          activityStartDateIso: activityStartDateIso,
          eventDateIso: eventDateIso,
        );
        if (!isTimeValid) continue;

        final bool isLocationValid = _validator.validateLocation(
          activityLat: _toDouble(activity['start_lat']),
          activityLng: _toDouble(activity['start_lng']),
          eventLat: eventLat,
          eventLng: eventLng,
        );
        if (!isLocationValid) continue;

        final int diffSeconds =
            DateTime.parse(activityStartDateIso)
                .toUtc()
                .difference(DateTime.parse(eventDateIso).toUtc())
                .inSeconds
                .abs();

        candidates.add(
          _Candidate(
            activityId: activity['activity_id'],
            diffSeconds: diffSeconds,
          ),
        );
      }

      // Her event için adayları, evente en yakın olan en başta olacak şekilde sırala.
      candidates.sort((a, b) => a.diffSeconds.compareTo(b.diffSeconds));
      candidatesByEvent[eventId] = candidates;
    }

    // 2. AŞAMA: Eventleri, kendi en yakın adayının süre farkına göre sırala.
    // (Senaryo 4: iki event aynı aktiviteyi istiyorsa, evente daha yakın olan kazanır.)
    final List<String> processingOrder =
        candidatesByEvent.keys.toList()..sort((a, b) {
          final int diffA =
              candidatesByEvent[a]!.isNotEmpty
                  ? candidatesByEvent[a]!.first.diffSeconds
                  : 1 << 31;
          final int diffB =
              candidatesByEvent[b]!.isNotEmpty
                  ? candidatesByEvent[b]!.first.diffSeconds
                  : 1 << 31;
          return diffA.compareTo(diffB);
        });

    // 3. AŞAMA: Sırayla her evente, henüz kullanılmamış en yakın adayı ata.
    final Set<dynamic> usedActivityIds = {};
    final Map<String, dynamic> result = {};

    for (final eventId in processingOrder) {
      dynamic assignedActivityId;

      for (final candidate in candidatesByEvent[eventId]!) {
        if (!usedActivityIds.contains(candidate.activityId)) {
          assignedActivityId = candidate.activityId;
          usedActivityIds.add(candidate.activityId);
          break;
        }
      }

      result[eventId] = assignedActivityId; // null ise -> missed
    }

    return result;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

class _Candidate {
  final dynamic activityId;
  final int diffSeconds;

  _Candidate({required this.activityId, required this.diffSeconds});
}
