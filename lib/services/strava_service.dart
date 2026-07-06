// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class StravaService {
  final _supabase = Supabase.instance.client;

  // Aktiviteleri çekme ve senkronize etme fonksiyonu
  Future<void> syncRecentActivities(String accessToken, int stravaId) async {
    print('Senkronizasyon başlıyor...');

    // 1. Zaman Makinesi: Tam 7 gün öncesini hesapla ve Unix (Saniye) formatına çevir
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final epochTime = sevenDaysAgo.millisecondsSinceEpoch ~/ 1000;

    // 2. Strava API İstek Adresi (after parametresi ile sadece bu tarihten sonrasını istiyoruz)
    final url = Uri.parse(
      'https://www.strava.com/api/v3/athlete/activities?after=$epochTime',
    );

    try {
      // 3. İsteği VIP kartımızla (Access Token) yapıyoruz
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> activities = jsonDecode(response.body);
        print(
          'BİNGO! Son 7 güne ait ${activities.length} adet aktivite başarıyla çekildi.',
        );

        // Çekilen her bir aktiviteyi döngüye alıp veritabanına işliyoruz
        for (var activity in activities) {
          // Strava koordinatları [enlem, boylam] şeklinde bir dizi olarak verir, bunu parçalıyoruz
          final latLng = activity['start_latlng'] as List<dynamic>?;
          final startLat =
              (latLng != null && latLng.isNotEmpty) ? latLng[0] : null;
          final startLng =
              (latLng != null && latLng.length > 1) ? latLng[1] : null;

          // SQL Tablona birebir uyumlu, eksiksiz veri haritası
          final activityData = {
            'activity_id': activity['id'],
            'strava_id': stravaId,
            'name': activity['name'], // Eklenen sütun
            'moving_time': activity['moving_time'], // Eklenen sütun
            'distance_meters': activity['distance'],
            'average_speed': activity['average_speed'],
            'start_date': activity['start_date'],
            'start_lat': startLat,
            'start_lng': startLng,
          };

          // Upsert: Duplicate (Çift kayıt) kontrolü yaparak kaydet
          await _supabase
              .from('activities')
              .upsert(activityData, onConflict: 'activity_id');
        }

        print(
          'Harika! Tüm aktiviteler Supabase activities tablosuna kaydedildi/güncellendi.',
        );

        // TODO: Bir sonraki adımda bu listeyi döngüye sokup Supabase'deki 'activities' tablosuna yazacağız.
      } else {
        print('Strava verileri vermedi. Hata Kodu: ${response.statusCode}');
        print('Hata Detayı: ${response.body}');
      }
    } catch (e) {
      print('İnternet veya bağlantı hatası: $e');
    }
  }
}
