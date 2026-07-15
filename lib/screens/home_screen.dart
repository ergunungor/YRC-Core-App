import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:yrc_core_app/screens/events_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'arena_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;

  // Premium Vurgu Renkleri
  final Color stravaOrange = const Color(0xFFFC4C02);
  final Color nikeVolt = const Color(0xFFCEFF00);
  final Color neonBlue = const Color(0xFF82B1F2);

  final List<Widget> _screens = [
    const EventsScreen(),
    const LeaderboardScreen(),
    const ArenaScreen(),
    const ProfileScreen(),
  ];

  Color getActiveColor() {
    switch (_currentIndex) {
      case 0:
        return neonBlue;
      case 1:
        return stravaOrange;
      case 2:
        return nikeVolt;
      case 3:
        return Colors.white;
      default:
        return stravaOrange;
    }
  }

  // İkonları ve "damlanın dışına taşan" parlama efektini oluşturan özel widget
  Widget _buildNavItem(IconData icon, int index) {
    bool isActive = _currentIndex == index;
    Color activeColor = getActiveColor();

    return Container(
      // Genişliği artırıyoruz ki ışık damlanın (butonun) çeperini aşıp dışarı yayılsın
      padding: const EdgeInsets.all(8.0),
      decoration:
          isActive
              ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withAlpha((0.5 * 255).round()),
                    blurRadius:
                        30, // Işığın dışarıya doğru çok daha yumuşak ve geniş dağılması
                    spreadRadius:
                        8, // İŞTE SİHİR: Gölgenin kendi sınırından çıkıp damlayı aşmasını sağlar
                  ),
                ],
              )
              : const BoxDecoration(),
      child: Icon(
        icon,
        size: 30, // İkonu da damlaya daha tok oturması için bir tık büyüttük
        color: isActive ? const Color(0xFF050B14) : Colors.white54,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B14),
      extendBody: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'YRC CORE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.0,
            fontSize: 20,
          ),
        ),
      ),

      body: _screens[_currentIndex],

      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        height: 60,
        backgroundColor: Colors.transparent,
        color: const Color(0xFF0A121F),

        buttonBackgroundColor: getActiveColor(),

        animationDuration: const Duration(milliseconds: 300),
        animationCurve: Curves.easeInOut,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          // İkonları yeni oluşturduğumuz dışa parlayan fonksiyon ile çağırıyoruz
          _buildNavItem(Icons.calendar_month, 0),
          _buildNavItem(Icons.leaderboard_rounded, 1),
          _buildNavItem(Icons.directions_run, 2),
          _buildNavItem(Icons.person, 3),
        ],
      ),
    );
  }
}
