// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class StravaService {
  final _supabase = Supabase.instance.client;

  // --- ANA SENKRONİZASYON FONKSİYONU ---
  Future<void> syncRecentActivities(String accessToken, int stravaId) async {
    print('Senkronizasyon başlıyor...');

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final epochTime = sevenDaysAgo.millisecondsSinceEpoch ~/ 1000;
    final sevenDaysAgoIso = sevenDaysAgo.toIso8601String();

    final url = Uri.parse(
      'https://www.strava.com/api/v3/athlete/activities?after=$epochTime',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> activities = jsonDecode(response.body);
        print(
          'BİNGO! Son 7 güne ait ${activities.length} adet aktivite başarıyla çekildi.',
        );

        int addedRunsCount = 0;

        for (var activity in activities) {
          final String activityType = activity['type'] ?? 'Unknown';
          if (activityType != 'Run') {
            print(
              'Filtrelendi: "${activity['name']}" bir koşu değil. Atlanıyor...',
            );
            continue;
          }

          final latLng = activity['start_latlng'] as List<dynamic>?;
          final startLat =
              (latLng != null && latLng.isNotEmpty) ? latLng[0] : null;
          final startLng =
              (latLng != null && latLng.length > 1) ? latLng[1] : null;

          final activityData = {
            'activity_id': activity['id'],
            'strava_id': stravaId,
            'name': activity['name'],
            'moving_time': activity['moving_time'],
            'distance_meters': activity['distance'],
            'average_speed': activity['average_speed'],
            'total_elevation_gain': activity['total_elevation_gain'] ?? 0,
            'start_date': activity['start_date'],
            'start_lat': startLat,
            'start_lng': startLng,
          };

          await _supabase
              .from('activities')
              .upsert(activityData, onConflict: 'activity_id');
          addedRunsCount++;
        }

        print(
          'Harika! $addedRunsCount adet KOŞU Supabase tablona kaydedildi/güncellendi.',
        );

        // --- ÇÖPÇÜ SİSTEMİ ---
        final List<int> currentRunIds =
            activities
                .where((a) => a['type'] == 'Run')
                .map<int>((a) => a['id'] as int)
                .toList();

        if (currentRunIds.isNotEmpty) {
          await _supabase
              .from('activities')
              .delete()
              .eq('strava_id', stravaId)
              .gte('start_date', sevenDaysAgoIso)
              .not('activity_id', 'in', currentRunIds);
        } else {
          await _supabase
              .from('activities')
              .delete()
              .eq('strava_id', stravaId)
              .gte('start_date', sevenDaysAgoIso);
        }

        print(
          'Temizlik tamamlandı! Strava\'dan silinen hayalet koşular uçuruldu.',
        );
      } else {
        print('Strava verileri vermedi. Hata Kodu: ${response.statusCode}');
        print('Hata Detayı: ${response.body}');
      }
    } catch (e) {
      print('İnternet veya bağlantı hatası: $e');
    }
  }

  // --- DOĞRULAMA İÇİN SON AKTİVİTEYİ ÇEKME FONKSİYONU ---
  Future<Map<String, dynamic>?> getLatestActivity(String accessToken) async {
    // per_page=1 parametresi ile sadece en son aktiviteyi getiriyoruz
    final url = Uri.parse(
      'https://www.strava.com/api/v3/athlete/activities?per_page=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> activities = jsonDecode(response.body);

        if (activities.isEmpty) {
          print('Strava hesabında hiç aktivite bulunamadı.');
          return null;
        }

        final activity = activities.first;
        final latLng = activity['start_latlng'] as List<dynamic>?;

        final startLat =
            (latLng != null && latLng.isNotEmpty) ? latLng[0] : null;
        final startLng =
            (latLng != null && latLng.length > 1) ? latLng[1] : null;

        // İstediğimiz formatta sadeleştirip döndürüyoruz
        return {
          'activity_id': activity['id'],
          'type': activity['type'], // 'Run' kontrolü için
          'start_date':
              activity['start_date'], // 3. Görev: Saat doğrulaması için
          'start_lat': startLat, // 4. Görev: Konum doğrulaması için
          'start_lng': startLng, // 4. Görev: Konum doğrulaması için
          'distance_meters': activity['distance'],
          'moving_time': activity['moving_time'],
          'average_speed': activity['average_speed'],
        };
      } else {
        print('Strava API Hatası Kodu: ${response.statusCode}');
        print('Strava API Hata Detayı: ${response.body}');
        return null;
      }
    } catch (e) {
      print('İnternet veya bağlantı hatası (getLatestActivity): $e');
      return null;
    }
  }

  // --- YENİ: EVENT BAZLI EŞLEŞTİRME İÇİN GÜNÜN TÜM AKTİVİTELERİNİ ÇEKME ---
  //
  // Strava API'ye tekrar gitmiyor; syncRecentActivities ile zaten Supabase'e
  // yazılmış "activities" tablosundan, event'in bulunduğu güne ait TÜM
  // aktiviteleri (sadece son aktiviteyi değil) çeker.
  Future<List<Map<String, dynamic>>> getActivitiesForDay({
    required int stravaId,
    required DateTime eventDate,
  }) async {
    try {
      final DateTime eventDateUtc = eventDate.toUtc();

      // Gün başlangıcından 3 saat öncesi, gün sonundan sonra 3 saat fazlası:
      // gece yarısına yakın etkinlikler ve saat toleransı için güvenlik payı.
      final DateTime windowStart = DateTime.utc(
        eventDateUtc.year,
        eventDateUtc.month,
        eventDateUtc.day,
      ).subtract(const Duration(hours: 3));

      final DateTime windowEnd = windowStart.add(const Duration(hours: 30));

      final response = await _supabase
          .from('activities')
          .select('activity_id, start_date, start_lat, start_lng')
          .eq('strava_id', stravaId)
          .gte('start_date', windowStart.toIso8601String())
          .lte('start_date', windowEnd.toIso8601String())
          .order('start_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print(
        '🚨 Günün aktiviteleri getirilirken hata (getActivitiesForDay): $e',
      );
      return [];
    }
  }
}
