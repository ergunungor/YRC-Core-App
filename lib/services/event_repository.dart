// ignore_for_file: avoid_print

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_type.dart';
import 'strava_service.dart';
import 'activity_validator_service.dart';

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

  /// 2. AŞAMA: Etkinliği veritabanına kaydeder. (GÜNCELLENDİ)
  Future<void> createEvent({
    required String title,
    required EventType type,
    required DateTime date,
    required String location,
    String? distance,
    String? pace,
    required String coverImageUrl,
    required int stravaId,
    required double lat, // YENİ EKLENDİ
    required double lng, // YENİ EKLENDİ
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
        'lat': lat, // YENİ EKLENDİ
        'lng': lng, // YENİ EKLENDİ
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

  /// 4. AŞAMA: Bir etkinliğe katılma (Join) veya iptal etme (Cancelled) işlemi
  Future<void> toggleParticipation({
    required String eventId,
    required int stravaId,
    required bool isJoining,
  }) async {
    try {
      // isJoining true ise 'joined', false ise 'cancelled' durumunu doğrudan veritabanına eziyoruz.
      // Bu sayede update'in satır bulamama veya RLS'e takılma ihtimalini ortadan kaldırıyoruz.
      await _supabase.from('event_participants').upsert({
        'event_id': eventId,
        'strava_id': stravaId,
        'status': isJoining ? 'joined' : 'cancelled',
      }, onConflict: 'event_id, strava_id');
    } catch (e) {
      // Eğer loglama sistemin varsa buraya ekleyebilirsin
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

  // --- 5. AŞAMA: OTOMATİK STRAVA DOĞRULAMA (ORKESTRATÖR) ---

  /// Kullanıcının son koşusunu çeker, etkinlik saati ve konumuyla kıyaslar,
  /// eşleşirse durumunu 'checked_in' yapar.
  Future<void> verifyAndCheckIn({
    required String eventId,
    required int stravaId,
    required String accessToken,
    required String eventDateIso,
    required double eventLat,
    required double eventLng,
  }) async {
    try {
      final stravaService = StravaService();
      final validator = ActivityValidatorService();

      // 1. Son aktiviteyi çek (Sadece en sonuncuya bakıyoruz)
      final activity = await stravaService.getLatestActivity(accessToken);
      if (activity == null || activity['type'] != 'Run') {
        return; // Koşu değilse çık
      }
      // 2. Saat Doğrulaması (Validator Servisimiz çalışıyor)
      final isTimeValid = validator.validateTime(
        activityStartDateIso: activity['start_date'],
        eventDateIso: eventDateIso,
      );

      if (!isTimeValid) {
        return; // Saat uymuyorsa konuma bakıp API/İşlemci yormaya gerek yok
      }
      // 3. Konum Doğrulaması (Haversine Formülü çalışıyor)
      final isLocValid = validator.validateLocation(
        activityLat: activity['start_lat'] ?? 0.0,
        activityLng: activity['start_lng'] ?? 0.0,
        eventLat: eventLat,
        eventLng: eventLng,
      );

      // 4. İki şart da sağlanıyorsa durumu 'checked_in' (Doğrulandı) yap
      // 4. İki şart da sağlanıyorsa durumu 'checked_in' (Doğrulandı) yap ve aktiviteyi bağla
      if (isLocValid) {
        await _supabase
            .from('event_participants')
            .update({
              'status': 'checked_in',
              'activity_id': activity['id'], // <-- SADECE BU SATIRI EKLEDİK
            })
            .match({'event_id': eventId, 'strava_id': stravaId});

        print(
          '✅ BİNGO! Koşu doğrulandı ve kullanıcı YRC Etkinliğine check-in yaptı.',
        );
      }
    } catch (e) {
      print('🚨 Doğrulama sırasında hata: $e');
    }
  }

  // --- 6. AŞAMA: PROFİL YENİLENDİĞİNDE BEKLEYEN ETKİNLİKLERİ DOĞRULA ---
  Future<void> validatePendingEvents(int stravaId, String accessToken) async {
    try {
      // 1. Kullanıcının 'joined' statüsünde olduğu etkinlikleri buluyoruz.
      // Supabase'in !inner join özelliği ile event_participants ve events tablolarını birleştirip etkinlik saatini/konumunu da alıyoruz.
      final pendingEvents = await _supabase
          .from('event_participants')
          .select('event_id, events!inner(date, lat, lng)')
          .match({'strava_id': stravaId, 'status': 'joined'});

      if (pendingEvents.isEmpty) {
        return;
      } // Bekleyen doğrulama yoksa işlemi bitir

      // 2. Bekleyen her etkinlik için bizim orkestratör motorumuzu çalıştır
      for (var row in pendingEvents) {
        final event = row['events'];

        await verifyAndCheckIn(
          eventId: row['event_id'],
          stravaId: stravaId,
          accessToken: accessToken,
          eventDateIso: event['date'],
          // UFAK BİR NOT: Eğer events tablosunda lat/lng yoksa, etkinlik oluştururken bunları da eklemelisin!
          eventLat:
              event['lat'] != null ? (event['lat'] as num).toDouble() : 0.0,
          eventLng:
              event['lng'] != null ? (event['lng'] as num).toDouble() : 0.0,
        );
      }
    } catch (e) {
      print('🚨 Bekleyen etkinlikler doğrulanırken hata: $e');
    }
  }
}
