import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/strava_service.dart'; // Dosya yolunun doğru olduğuna emin ol

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A365D), // Tok gece mavisi arka plan
      appBar: AppBar(
        title: const Text(
          'YRC Core',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0),
        ),
        centerTitle: true,
        backgroundColor:
            Colors.transparent, // AppBar'ı arka planla bütünleştiriyoruz
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'İçeridesin!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Strava verilerin buraya akacak.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 40),
              child: ElevatedButton(
                onPressed: () async {
                  final supabase = Supabase.instance.client;
                  final stravaService = StravaService();

                  try {
                    print('Veritabanından Token aranıyor...');

                    // 1. VIP Anahtarı ve Kullanıcı ID'sini Supabase'den çek
                    final userData =
                        await supabase.from('users').select().limit(1).single();

                    final accessToken = userData['access_token'];
                    final stravaId = userData['strava_id'];

                    print('Token bulundu! Strava API\'ye gidiliyor...');

                    // 2. Servisi çalıştırıp son 7 günün koşularını iste
                    await stravaService.syncRecentActivities(
                      accessToken,
                      stravaId,
                    );
                  } catch (e) {
                    print('Veri çekme sırasında hata: $e');
                  }
                },
                child: const Text('Strava Verilerini Getir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
