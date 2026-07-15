import 'package:supabase_flutter/supabase_flutter.dart';

/// Pacer başvuru ve onay işlemlerinden sorumlu servis.
class PacerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- KULLANICI TARAFI ---

  /// Kullanıcının mevcut rolünü döndürür ('user' | 'pacer' | 'admin').
  Future<String> getMyRole(int stravaId) async {
    try {
      final row =
          await _supabase
              .from('users')
              .select('role')
              .eq('strava_id', stravaId)
              .maybeSingle();

      return row?['role'] as String? ?? 'user';
    } catch (e) {
      return 'user';
    }
  }

  /// Kullanıcının en son başvurusunun durumunu döndürür.
  /// Hiç başvuru yoksa null döner.
  Future<String?> getMyLatestApplicationStatus(int stravaId) async {
    try {
      final row =
          await _supabase
              .from('pacer_applications')
              .select('status')
              .eq('strava_id', stravaId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

      return row?['status'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Pacer olmak için başvuru oluşturur.
  /// Zaten pacer/admin ise veya bekleyen bir başvurusu varsa hata fırlatır.
  Future<void> applyForPacer(int stravaId) async {
    final currentRole = await getMyRole(stravaId);
    if (currentRole == 'pacer' || currentRole == 'admin') {
      throw Exception('Zaten Pacer rütbesine sahipsiniz.');
    }

    final pendingStatus = await getMyLatestApplicationStatus(stravaId);
    if (pendingStatus == 'pending') {
      throw Exception('Zaten bekleyen bir başvurunuz var.');
    }

    try {
      await _supabase.from('pacer_applications').insert({
        'strava_id': stravaId,
        'status': 'pending',
      });
    } on PostgrestException catch (e) {
      // unique index (bir kullanıcı sadece bir pending başvuru yapabilir)
      throw Exception('Başvuru gönderilemedi: ${e.message}');
    }
  }

  // --- ADMIN TARAFI ---

  /// Bekleyen tüm başvuruları, başvuran kullanıcının bilgileriyle birlikte getirir.
  Future<List<Map<String, dynamic>>> fetchPendingApplications() async {
    final applications = await _supabase
        .from('pacer_applications')
        .select('id, strava_id, status, created_at')
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    if (applications.isEmpty) return [];

    final stravaIds = applications.map((a) => a['strava_id']).toList();

    final users = await _supabase
        .from('users')
        .select('strava_id, first_name, last_name, avatar_url')
        .inFilter('strava_id', stravaIds);

    final Map<dynamic, Map<String, dynamic>> usersById = {
      for (final u in users) u['strava_id']: u,
    };

    return applications.map((app) {
      final user = usersById[app['strava_id']];
      return {
        'id': app['id'],
        'strava_id': app['strava_id'],
        'status': app['status'],
        'created_at': app['created_at'],
        'first_name': user?['first_name'],
        'last_name': user?['last_name'],
        'avatar_url': user?['avatar_url'],
      };
    }).toList();
  }

  /// Başvuruyu onaylar: hem başvuru durumunu hem kullanıcının role'ünü günceller.
  Future<void> approveApplication({
    required String applicationId,
    required int stravaId,
  }) async {
    await _supabase
        .from('pacer_applications')
        .update({
          'status': 'approved',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', applicationId);

    await _supabase
        .from('users')
        .update({'role': 'pacer'})
        .eq('strava_id', stravaId);
  }

  /// Başvuruyu reddeder. Kullanıcının role'üne dokunmaz.
  Future<void> rejectApplication(String applicationId) async {
    await _supabase
        .from('pacer_applications')
        .update({
          'status': 'rejected',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', applicationId);
  }
}
