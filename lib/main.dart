import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yrc_core_app/screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/admin_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

void main() async {
  // Flutter motorunun tamamen hazır olduğundan emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

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
      home: const AuthGate(),
      routes: {'/admin': (context) => const AdminLoginScreen()},
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isChecking = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final stravaId = prefs.getInt('current_strava_id');

    if (mounted) {
      setState(() {
        _hasSession = stravaId != null;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
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
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Image.asset(
                'assets/images/logo-Photoroom.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }

    return _hasSession ? const HomeScreen() : const LoginScreen();
  }
}
