import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/event_card.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';

/// Full list of events opened from a home-page section's "See all" action.
class EventListPage extends StatefulWidget {
  const EventListPage({
    super.key,
    required this.title,
    required this.events,
    this.imageByEvent = const {},
    this.wishCounts = const {},
    this.savedIds = const {},
    this.onToggleWish,
    this.onEventTap,
  });

  final String title;
  final List<EventModel> events;
  final Map<int, EventImageModel> imageByEvent;
  final Map<int, int> wishCounts;
  final Set<int> savedIds;
  final Future<void> Function(EventModel event)? onToggleWish;
  final void Function(EventModel event)? onEventTap;

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  late Set<int> _savedIds;

  @override
  void initState() {
    super.initState();
    _savedIds = Set<int>.of(widget.savedIds);
  }

  Future<void> _toggleWish(EventModel event) async {
    final wasSaved = _savedIds.contains(event.id);
    setState(() {
      if (wasSaved) {
        _savedIds.remove(event.id);
      } else {
        _savedIds.add(event.id);
      }
    });
    await widget.onToggleWish?.call(event);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < widget.events.length; i += 2) {
      final first = widget.events[i];
      final second = i + 1 < widget.events.length ? widget.events[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _card(first)),
              const SizedBox(width: 12),
              if (second != null)
                Expanded(child: _card(second))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212121),
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: widget.events.isEmpty
          ? const Center(
              child: Text(
                'No events yet.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: rows,
            ),
    );
  }

  Widget _card(EventModel event) {
    return EventCard(
      event: event,
      image: widget.imageByEvent[event.id],
      attend: widget.wishCounts[event.id] ?? 0,
      saved: _savedIds.contains(event.id),
      onSaveTap: widget.onToggleWish == null
          ? null
          : () => _toggleWish(event),
      onTap: widget.onEventTap == null ? null : () => widget.onEventTap!(event),
    );
  }
}