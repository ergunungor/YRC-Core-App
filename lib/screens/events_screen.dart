import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; // Glassmorphism efekti için
import 'package:intl/intl.dart'; // Tarih formatlama için
import 'package:shared_preferences/shared_preferences.dart';

import 'create_event_screen.dart';
import '../services/event_repository.dart';
import '../models/event_type.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventRepository _repository = EventRepository();
  final Color bgColor = const Color(0xFF01132A);

  // DÜZELTME: Değişken sınıf seviyesine taşındı.
  int? _currentStravaId;

  @override
  void initState() {
    super.initState();
    _loadStravaId();
  }

  Future<void> _loadStravaId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentStravaId = prefs.getInt('current_strava_id');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,

      // StreamBuilder ile Supabase'den etkinlikleri anlık (real-time) dinliyoruz
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _repository.getEventsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final events = snapshot.data ?? [];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),

              if (events.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      _buildDynamicEventList(events),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // --- SİLVER APP BAR ---
  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: bgColor.withValues(alpha: 0.7),
      pinned: true,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color.fromARGB(255, 86, 187, 255),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(
                    255,
                    103,
                    237,
                    255,
                  ).withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () async {
                HapticFeedback.lightImpact();
                final prefs = await SharedPreferences.getInstance();

                final stravaId = prefs.getInt('current_strava_id');

                if (!context.mounted) return;

                if (stravaId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kullanıcı bilgisi bulunamadı.'),
                    ),
                  );
                  return;
                }

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => EventCreateScreen(currentStravaId: stravaId),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Events',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.filter_list_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => HapticFeedback.lightImpact(),
          ),
        ),
      ],
    );
  }

  // --- DİNAMİK LİSTE OLUŞTURUCU ---
  List<Widget> _buildDynamicEventList(List<Map<String, dynamic>> events) {
    List<Widget> listItems = [];
    bool isThisWeekHeaderAdded = false;
    bool isFutureHeaderAdded = false;

    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));

    for (var eventData in events) {
      DateTime eventDate = DateTime.parse(eventData['date']);

      if (eventDate.isBefore(now.subtract(const Duration(hours: 4)))) continue;

      bool isThisWeek = eventDate.isBefore(sevenDaysLater);

      if (isThisWeek && !isThisWeekHeaderAdded) {
        listItems.add(_buildSectionHeader('BU HAFTA'));
        listItems.add(const SizedBox(height: 16));
        isThisWeekHeaderAdded = true;
      } else if (!isThisWeek && !isFutureHeaderAdded) {
        listItems.add(_buildSectionHeader('GELECEK ETKİNLİKLER'));
        listItems.add(const SizedBox(height: 16));
        isFutureHeaderAdded = true;
      }

      listItems.add(_buildEventCardFromData(eventData));
      listItems.add(const SizedBox(height: 32));
    }

    if (listItems.isEmpty) return [_buildEmptyState()];
    return listItems;
  }

  // --- VERİDEN KART OLUŞTURMA (DÜZELTİLDİ) ---
  Widget _buildEventCardFromData(Map<String, dynamic> eventData) {
    DateTime date = DateTime.parse(eventData['date']);
    EventType type = EventTypeHelper.fromDbValue(eventData['type']);
    final String eventId = eventData['id'];

    Color badgeColor;
    switch (type) {
      case EventType.longRun:
        badgeColor = const Color(0xFF4C9EEB);
        break;
      case EventType.socialRun:
        badgeColor = const Color(0xFF34C759);
        break;
      case EventType.interval:
        badgeColor = const Color(0xFFFC4C02);
        break;
      case EventType.tempo:
        badgeColor = const Color(0xFF9C27B0);
        break;
      case EventType.recovery:
        badgeColor = const Color(0xFF00C7BE);
        break;
      case EventType.race:
        badgeColor = const Color(0xFFFF3B30);
        break;
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _repository.getEventParticipantsStream(eventId),
      builder: (context, participantSnapshot) {
        final participants = participantSnapshot.data ?? [];
        final participantsCount = participants.length;

        // Kullanıcı bu etkinliğe katılmış mı kontrolü
        final bool isJoined =
            _currentStravaId != null &&
            participants.any((p) => p['strava_id'] == _currentStravaId);

        return ImmersiveEventCard(
          imageUrl: eventData['cover_image_url'] ?? '',
          month: DateFormat('MMM', 'tr_TR').format(date).toUpperCase(),
          day: DateFormat('dd').format(date),
          badgeText: type.uiLabel.toUpperCase(),
          badgeColor: badgeColor,
          title: eventData['title'] ?? 'İsimsiz Etkinlik',
          time: DateFormat('EEEE • hh:mm a', 'tr_TR').format(date),
          location: eventData['location'] ?? 'Konum Belirtilmedi',
          distance: eventData['distance'] ?? '-',
          pace: eventData['pace'] ?? '-',
          participants: participantsCount,
          isJoined: isJoined,
          avatarUrls: const [],
          // DÜZELTME: onJoinTap tanımlandı ve aksiyon eklendi
          onJoinTap: () async {
            if (_currentStravaId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kullanıcı bilgisi yüklenemedi.')),
              );
              return;
            }

            try {
              await _repository.toggleParticipation(
                eventId: eventId,
                stravaId: _currentStravaId!,
                isJoining: !isJoined,
              );
              HapticFeedback.mediumImpact();
            } // Mevcut catch bloğunu bununla değiştir
            catch (e) {
              print('🚨 SUPABASE KATILIM HATASI: $e'); // Terminalde görmek için
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.5),
          letterSpacing: 2.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 100, left: 24, right: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 80,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 24),
          const Text(
            'Planlanmış Koşu Yok',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pacer\'larımız yeni rotalar hazırlıyor.\nAyakkabılarını hazırda tut!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: bgColor,
      body: const Center(
        child: CircularProgressIndicator(color: Color(0xFFFC4C02)),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Text(
          'Bir hata oluştu:\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

// --- IMMERSIVE EVENT CARD WIDGET'IN ---
class ImmersiveEventCard extends StatelessWidget {
  final String imageUrl;
  final String month;
  final String day;
  final String badgeText;
  final Color badgeColor;
  final String title;
  final String time;
  final String location;
  final String distance;
  final String pace;
  final int participants;
  final bool isJoined;
  final List<String> avatarUrls;
  // DÜZELTME: onJoinTap parametresi tanımlandı
  final VoidCallback onJoinTap;

  const ImmersiveEventCard({
    super.key,
    required this.imageUrl,
    required this.month,
    required this.day,
    required this.badgeText,
    required this.badgeColor,
    required this.title,
    required this.time,
    required this.location,
    required this.distance,
    required this.pace,
    required this.participants,
    required this.isJoined,
    required this.avatarUrls,
    // DÜZELTME: Constructor'a eklendi
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. TAM EKRAN FOTOĞRAF (Boş URL Korumalı)
          if (imageUrl.trim().isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: const Color(0xFF0F172A),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white24),
                  ),
                );
              },
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    color: const Color(0xFF0F172A),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: Colors.white24,
                        size: 50,
                      ),
                    ),
                  ),
            )
          else
            Container(
              color: const Color(0xFF0F172A),
              child: const Center(
                child: Icon(
                  Icons.directions_run_rounded,
                  color: Colors.white24,
                  size: 50,
                ),
              ),
            ),

          // 2. GRADIENT OVERLAY
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  const Color(0xFF01132A).withValues(alpha: 0.7),
                  const Color(0xFF01132A).withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.4, 0.75, 1.0],
              ),
            ),
          ),

          // 3. ÜST BADGELER (Tarih ve Tip)
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Text(
                        month,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: badgeColor,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        day,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildGlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: badgeColor,
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. ALT İÇERİK (Başlık, Lokasyon, Avatarlar, Buton)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4C9EEB),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMiniStat(
                        Icons.location_on_rounded,
                        location,
                        isLocation: true,
                      ),
                      const SizedBox(width: 12),
                      _buildMiniStat(Icons.route_rounded, distance),
                      const SizedBox(width: 12),
                      _buildMiniStat(Icons.speed_rounded, pace),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Avatarlar ve Buton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // SOL TARAF: Katılanlar
                      Expanded(
                        child: Row(
                          children: [
                            if (avatarUrls.isNotEmpty) ...[
                              _buildOverlappingAvatars(),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                avatarUrls.isEmpty && participants == 0
                                    ? 'İLK SEN KATIL'
                                    : '+${participants > 3 ? participants - 3 : participants} GİDİYOR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // SAĞ TARAF: Buton (DÜZELTME: onJoinTap buraya bağlandı)
                      InkWell(
                        onTap: onJoinTap,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isJoined
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFFC4C02),
                            borderRadius: BorderRadius.circular(30),
                            border:
                                isJoined
                                    ? Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1.5,
                                    )
                                    : null,
                            boxShadow:
                                isJoined
                                    ? null
                                    : [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFC4C02,
                                        ).withValues(alpha: 0.7),
                                        blurRadius: 20,
                                        spreadRadius: 4,
                                      ),
                                    ],
                          ),
                          child: Text(
                            isJoined ? 'KATILDIN' : 'BİRLİKTE KOŞ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: isJoined ? Colors.white : Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    required EdgeInsets padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text, {bool isLocation = false}) {
    return Expanded(
      flex: isLocation ? 2 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // TAŞMA SORUNU ÇÖZÜLEN AVATAR KISMI
  Widget _buildOverlappingAvatars() {
    if (avatarUrls.isEmpty) return const SizedBox.shrink();

    final int count = avatarUrls.length > 3 ? 3 : avatarUrls.length;
    final double containerWidth = (count - 1) * 22.0 + 32.0;

    return SizedBox(
      width: containerWidth,
      height: 32,
      child: Stack(
        children: List.generate(count, (index) {
          return Positioned(
            left: index * 22.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF01132A), width: 2),
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundImage: NetworkImage(avatarUrls[index]),
              ),
            ),
          );
        }),
      ),
    );
  }
}
