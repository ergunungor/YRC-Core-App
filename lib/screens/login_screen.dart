// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yrc_core_app/screens/home_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // Uygulamanın web'de mi mobilde mi olduğunu anlamamızı sağlar
import 'dart:async';
import 'package:app_links/app_links.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Uygulama açıkken gelen linkleri dinliyoruz
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      print('SİSTEM: Uygulamaya şu linkle dönüldü: $uri');

      // Linkin içinde Strava'nın verdiği 'code' var mı diye bakıyoruz
      if (uri.queryParameters.containsKey('code')) {
        final authCode = uri.queryParameters['code']!;

        print('HARİKA! Strava kodu yakalandı: $authCode');

        // Kodu yakaladığımıza göre, dünkü token takas fonksiyonumuzu çalıştırabiliriz!
        _exchangeCodeForToken(authCode);
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _checkStravaRedirect() {
    final uri = Uri.base;

    if (uri.queryParameters.containsKey('code')) {
      final authCode = uri.queryParameters['code']!;
      print('Strava Yetki Kodu Yakalandı, takas ediliyor: $authCode');

      // Yakaladığımız kodu token'lara çevirmek için fonksiyona gönderiyoruz
      _exchangeCodeForToken(authCode);
    }
  }

  Future<void> _exchangeCodeForToken(String authCode) async {
    const String clientId = '262903';
    const String clientSecret =
        'b965b158fc3d49d12cb2073c79662a1b1ce5389c'; // Strava ayarlarından kopyaladığın gizli kod

    try {
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': authCode,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        final athleteData = data['athlete'];

        print('SÜPER! Access Token Alındı: $accessToken');

        // --- İŞTE KAYIT İŞLEMİ TAM BURADA YAPILIYOR ---
        try {
          final supabase = Supabase.instance.client;

          await supabase.from('users').upsert({
            'strava_id':
                athleteData['id'], // BIGINT olduğu için .toString() yok
            'first_name': athleteData['firstname'],
            'last_name': athleteData['lastname'],
            'profile_url': athleteData['profile'],
            'access_token': accessToken,
            'refresh_token': refreshToken,
          });

          print('BINGO! Kullanıcı veritabanına başarıyla kaydedildi!');
        } catch (dbError) {
          print('Supabase Kayıt Hatası: $dbError');
        }
        // ----------------------------------------------
        if (!kIsWeb) {
          closeInAppWebView();
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        print('Token takası başarısız: ${response.body}');
      }
    } catch (e) {
      print('İnternet veya sunucu hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 130, 177, 242),
              Color.fromARGB(255, 1, 19, 42),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // Sabit Boyutlu ve Büyütülmüş Logolu Tasarım
              Container(
                width: 150,
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo-Photoroom.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'YRC Core',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                ' "we run in love" ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 60),

              // Neon Parlama Efektli Strava Butonu
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFC4C02).withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    const String clientId = '262903';
                    String redirectUri;
                    if (kIsWeb) {
                      redirectUri = Uri.base.origin; // Chrome/Web için
                    } else {
                      redirectUri =
                          'yrccore://localhost'; // iOS ve Android için (Deep Link)
                    }
                    const String scope =
                        'read,activity:read_all,profile:read_all';

                    final Uri stravaAuthUrl = Uri.parse(
                      'https://www.strava.com/oauth/mobile/authorize'
                      '?client_id=$clientId'
                      '&response_type=code'
                      '&redirect_uri=$redirectUri'
                      '&approval_prompt=force'
                      '&scope=$scope',
                    );

                    // Senin önerdiğin "Sağlam" yapı: try-catch zırhı
                    try {
                      if (await canLaunchUrl(stravaAuthUrl)) {
                        await launchUrl(
                          stravaAuthUrl,
                          webOnlyWindowName: '_self',
                        );
                      } else {
                        // Tarayıcı yoksa veya link bozuksa buraya düşer
                        print('Cihaz bu URL yapısını desteklemiyor.');
                      }
                    } catch (e) {
                      // Beklenmedik bir çökme olursa uygulama patlamaz, hatayı yakalarız
                      print(
                        'Strava yönlendirmesi sırasında kritik bir hata oluştu: $e',
                      );
                    }
                  },
                  icon: const Icon(Icons.flash_on, color: Colors.white),
                  label: const Text(
                    'Strava ile Bağlan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC4C02),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // En Alt Kısım: İmza
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  'POWERED BY YILDIZ RUN CLUB',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.3),
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
