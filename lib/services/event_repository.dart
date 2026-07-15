import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_type.dart';

/// Event işlemlerinden sorumlu Repository sınıfı.
/// Veritabanı (Database) ve Depolama (Storage) işlemleri burada izole edilmiştir.
class EventRepository {
  // Supabase instance'ına her seferinde erişmek yerine bir referans alıyoruz
  final SupabaseClient _supabase = Supabase.instance.client;

  // Magic string'lerden kaçınmak için bucket ve tablo isimlerini sabitliyoruz
  static const String _tableName = 'events';
  static const String _bucketName = 'events';

  /// 1. AŞAMA: Fotoğrafı Supabase Storage'a yükler ve Public URL'sini döndürür.
  Future<String> uploadEventCoverImage(
    File imageFile,
    String fileExtension,
  ) async {
    try {
      final String fileName =
          'cover_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await _supabase.storage
          .from(_bucketName)
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);

      return publicUrl;
    } on StorageException catch (e) {
      throw Exception(
        'Fotoğraf yüklenirken depolama hatası oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Fotoğraf yüklenemedi. Lütfen internet bağlantınızı kontrol edin.',
      );
    }
  }

  /// 2. AŞAMA: Etkinliği veritabanına kaydeder.
  Future<void> createEvent({
    required String title,
    required EventType type,
    required DateTime date,
    required String location,
    String? distance,
    String? pace,
    required String coverImageUrl,
    required int stravaId,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'title': title.trim(),
        'type': type.dbValue,
        'date': date.toUtc().toIso8601String(),
        'location': location.trim(),
        if (distance != null && distance.trim().isNotEmpty)
          'distance': distance.trim(),
        if (pace != null && pace.trim().isNotEmpty) 'pace': pace.trim(),
        'cover_image_url': coverImageUrl,
        'created_by': stravaId,
      };

      await _supabase.from(_tableName).insert(payload);
    } on PostgrestException catch (e) {
      throw Exception('Etkinlik veritabanına kaydedilemedi: ${e.message}');
    } catch (e) {
      throw Exception('Etkinlik oluşturulurken beklenmeyen bir hata oluştu.');
    }
  }

  /// 3. AŞAMA: Tüm aktif etkinlikleri canlı (Stream) olarak getirir.
  Stream<List<Map<String, dynamic>>> getEventsStream() {
    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .eq('is_cancelled', false)
        .order('date', ascending: true);
  }

  /// ---------------------------------------------------------
  /// YENİ EKLENEN BÖLÜM: KATILIMCI (PARTICIPANT) İŞLEMLERİ
  /// ---------------------------------------------------------

  /// 4. AŞAMA: Bir etkinliğe katılma (Join) veya ayrılma (Leave) işlemi
  Future<void> toggleParticipation({
    required String eventId,
    required int stravaId,
    required bool isJoining,
  }) async {
    try {
      if (isJoining) {
        // KATIL: 'cancelled' olanları 'joined' yapmak veya yeni kayıt eklemek için upsert.
        // onConflict ile unique constraint'i (event_id, strava_id) belirtiyoruz.
        await _supabase.from('event_participants').upsert({
          'event_id': eventId,
          'strava_id': stravaId,
          'status': 'joined',
        }, onConflict: 'event_id, strava_id');
      } else {
        // AYRIL: Satırı silmiyoruz, veritabanı kuralımıza uygun olarak status'ü güncelliyoruz.
        await _supabase
            .from('event_participants')
            .update({'status': 'cancelled'})
            .match({'event_id': eventId, 'strava_id': stravaId});
      }
    } catch (e) {
      throw Exception('Katılım işlemi sırasında bir hata oluştu: $e');
    }
  }

  /// 4.1 AŞAMA: Kullanıcının etkinliğe katılıp katılmadığını (başlangıç durumu için) kontrol eder
  Future<bool> checkUserParticipation({
    required String eventId,
    required int stravaId,
  }) async {
    try {
      final response =
          await _supabase.from('event_participants').select('id').match({
            'event_id': eventId,
            'strava_id': stravaId,
            'status':
                'joined', // Sadece aktif olarak 'joined' olanları doğru kabul et
          }).maybeSingle();

      return response != null;
    } catch (e) {
      return false; // Hata durumunda UI tarafını çökertmemek için false dönüyoruz
    }
  }

  /// 5. AŞAMA: Bir etkinliğin katılımcı listesini CANLI dinler
  /// (Ana sayfadaki kartların içinde bu stream'i dinleyip sayıyı/avatarları güncelleyeceğiz)
  Stream<List<Map<String, dynamic>>> getEventParticipantsStream(
    String eventId,
  ) {
    // Supabase Stream'leri arka arkaya birden fazla .eq() filtresini desteklemez!
    // Bu yüzden ilk filtreyi veritabanında (event_id),
    // ikinci filtreyi ise telefonun hafızasında Dart'ın map metoduyla yapıyoruz.
    return _supabase
        .from('event_participants')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .map(
          (participants) =>
              participants.where((p) => p['status'] == 'joined').toList(),
        );
  }
}
