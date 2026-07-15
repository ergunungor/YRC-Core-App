import 'package:flutter/material.dart';
import '../services/event_repository.dart';

/// Her bir etkinlik kartı için katılımcı listesini canlı dinleyen widget.
class EventParticipantsWidget extends StatelessWidget {
  final String eventId;
  final EventRepository _repository = EventRepository();

  EventParticipantsWidget({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _repository.getEventParticipantsStream(eventId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            "Henüz katılan yok",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          );
        }

        final participants = snapshot.data!;

        return SizedBox(
          height: 30,
          child: Stack(
            children: List.generate(
              participants.length > 5 ? 5 : participants.length,
              (index) => Positioned(
                left: index * 20.0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF01132A),
                      width: 2,
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 13,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
