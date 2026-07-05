import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yrc_core_app/screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Fontu Montserrat olarak ayarlıyoruz
      theme: ThemeData(
        textTheme: GoogleFonts.montserratTextTheme(Theme.of(context).textTheme),
      ),
      home: const LoginScreen(),
    );
  }
}
