import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Flutter motorunun tamamen hazır olduğundan emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase'i uyandırıyoruz ve anahtarları veriyoruz
  await Supabase.initialize(
    url: 'https://zcxzukvzxmyvczeihpdz.supabase.co',
    publishableKey: 'sb_publishable_Mmf-UaejcwOBt_LtxHNqNg_PZiKlPKy',
  );

  // Uygulamanın motorunu çalıştıran ilk komut
  runApp(const YRCCoreApp());
}

class YRCCoreApp extends StatelessWidget {
  const YRCCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SupabaseTestEkrani(),
    );
  }
}

class SupabaseTestEkrani extends StatelessWidget {
  const SupabaseTestEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YRC Core - Gün 1 Testi'),
        centerTitle: true,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Veritabanındaki 'users' tablosuna gidip veri çekmeye çalışıyoruz
              final data =
                  await Supabase.instance.client.from('users').select();

              // Sonucu Android Studio'nun altındaki 'Run' veya 'Debug Console' sekmesine yazdırıyoruz
              // ignore: avoid_print
              print('🎉 BAĞLANTI BAŞARILI! Supabase Cevabı: $data');
            } catch (e) {
              // ignore: avoid_print
              print('❌ BAĞLANTI HATASI: $e');
            }
          },
          child: const Text('Veritabanına Bağlan'),
        ),
      ),
    );
  }
}
