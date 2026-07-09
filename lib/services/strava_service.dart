// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class StravaService {
  final _supabase = Supabase.instance.client;

  // Saniyeyi "18:30" gibi şık bir Pace/Süre formatına çeviren yardımcı alet
  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;

    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // PR (Best Effort) verilerini çekip User tablosuna yazma fonksiyonu
  Future<void> _extractAndSavePRs(
    String accessToken,
    int stravaId,
    int activityId,
  ) async {
    final url = Uri.parse(
      'https://www.strava.com/api/v3/activities/$activityId',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final activityDetail = jsonDecode(response.body);
        final List<dynamic> bestEfforts = activityDetail['best_efforts'] ?? [];

        if (bestEfforts.isNotEmpty) {
          // Güncellenecek kolonları toplayacağımız harita (Map)
          Map<String, dynamic> prUpdates = {};

          for (var effort in bestEfforts) {
            String prName =
                effort['name']; // "400m", "1 mile", "5k", "10k", "Half Marathon" vs.
            int elapsedTime = effort['elapsed_time']; // Koştuğu süre (saniye)

            // Strava'nın isimlerini bizim User tablosundaki kolonlara çeviriyoruz
            if (prName.toLowerCase().contains("400m")) {
              prUpdates['pr_400m'] = _formatTime(elapsedTime);
              prUpdates['pr_400m_sec'] =
                  elapsedTime; // Sıralama için gizli saniye kolonu (opsiyonel ama önerilir)
            } else if (prName.toLowerCase().contains("1 mile")) {
              prUpdates['pr_1mil'] = _formatTime(elapsedTime);
              prUpdates['pr_1mil_sec'] = elapsedTime;
            } else if (prName.toLowerCase().contains("3k") ||
                prName.toLowerCase().contains("2 mile")) {
              // Bazen 3k yerine 2 mile yazar Strava
              prUpdates['pr_3k'] = _formatTime(elapsedTime);
              prUpdates['pr_3k_sec'] = elapsedTime;
            } else if (prName.toLowerCase().contains("5k")) {
              prUpdates['pr_5k'] = _formatTime(elapsedTime);
              prUpdates['pr_5k_sec'] = elapsedTime;
            } else if (prName.toLowerCase().contains("10k")) {
              prUpdates['pr_10k'] = _formatTime(elapsedTime);
              prUpdates['pr_10k_sec'] = elapsedTime;
            } else if (prName.toLowerCase().contains("half")) {
              prUpdates['pr_21k'] = _formatTime(elapsedTime);
              prUpdates['pr_21k_sec'] = elapsedTime;
            }
          }

          // Eğer kullanıcının rekoru varsa ve harita dolduysa Supabase'deki Users tablosuna yapıştırıyoruz!
          if (prUpdates.isNotEmpty) {
            print(
              "👑 PR (Rekor) Yakalandı! Kullanıcı profiline (users tablosuna) güncelleniyor...",
            );

            // Supabase'deki kullanıcının MEVCUT PR saniyelerini çekip,
            // sadece GERÇEKTEN daha iyi (daha kısa) bir süreyse üstüne yazmak mantıklı olur.
            // (Şimdilik direkt yazıyoruz, demoda anında göstermek için ideal)
            await _supabase
                .from('users')
                .update(prUpdates)
                .eq('strava_id', stravaId);
          }
        }
      }
    } catch (e) {
      print('PR Detayı Çekilemedi: $e');
    }
  }

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
            'start_date': activity['start_date'],
            'start_lat': startLat,
            'start_lng': startLng,
          };

          await _supabase
              .from('activities')
              .upsert(activityData, onConflict: 'activity_id');
          addedRunsCount++;

          // 🚀 KRİTİK EKLEME: İdman eklendikten sonra hemen detayına inip PR (Best Efforts) var mı diye bakıyoruz!
          await _extractAndSavePRs(accessToken, stravaId, activity['id']);
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
}
