import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/wishlist_api_service.dart';

const Color _kAccent = Color(0xFF5B4DFF);
const Color _kPink = Color(0xFFEC407A);
const Color _kGrey = Color(0xFF9E9E9E);
const Color _kTextGrey = Color(0xFF757575);

class WishPanel extends StatefulWidget {
  const WishPanel({super.key});

  @override
  State<WishPanel> createState() => _WishPanelState();
}

class _WishPanelState extends State<WishPanel> {
  bool _loading = true;
  String? _error;

  List<EventModel> _events = [];
  Map<int, EventImageModel> _imageByEvent = {};
  Map<int, EventOrganizer> _organizerById = {};
  Map<int, int> _attendeeCountByEvent = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = AuthService.currentSession;
      final wishes = await _optional(
        WishlistApiService.getAllWishes,
        const <WishlistModel>[],
      );

      final myEventIds = <int>{};
      final attendeeCount = <int, int>{};
      for (final w in wishes) {
        attendeeCount[w.eventId] = (attendeeCount[w.eventId] ?? 0) + 1;
        if (session != null && w.accountId == session.accountId) {
          myEventIds.add(w.eventId);
        }
      }

      List<EventModel> events = [];
      if (myEventIds.isNotEmpty) {
        final allEvents = await EventApiService.getAllEvents();
        events =
            allEvents.where((e) => myEventIds.contains(e.id)).toList()
              ..sort((a, b) => a.start.compareTo(b.start));
      }

      final images = await _optional(
        EventImageApiService.getAllEventImages,
        const <EventImageModel>[],
      );
      final organizers = await _optional(
        EventApiService.getAllOrganizers,
        const <EventOrganizer>[],
      );

      final imageByEvent = <int, EventImageModel>{};
      for (final img in images) {
        if (img.isThumbnail || !imageByEvent.containsKey(img.eventId)) {
          imageByEvent[img.eventId] = img;
        }
      }

      if (!mounted) return;
      setState(() {
        _events = events;
        _imageByEvent = imageByEvent;
        _organizerById = {for (final o in organizers) o.id: o};
        _attendeeCountByEvent = attendeeCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static Future<T> _optional<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: RefreshIndicator(
          color: _kAccent,
          backgroundColor: Colors.white,
          onRefresh: _load,
          child: _loading && _events.isEmpty ? _loadingView() : _body(context),
        ),
      ),
    );
  }

  Widget _loadingView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 400,
          child: Center(child: CircularProgressIndicator(color: _kAccent)),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _header(topPad),
        const SizedBox(height: 16),
        if (_error != null && _events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _errorBox(),
          )
        else if (_events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _emptyState(context),
          )
        else
          ..._events.map(
            (e) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _wishCard(e),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _header(double topPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad + 16, 16, 0),
      child: Text(
        'Wish List',
        style: const TextStyle(
          color: Color(0xFF212121),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _wishCard(EventModel event) {
    final image = _imageByEvent[event.id];
    final organizer = _organizerById[event.organizerId]?.name ?? 'GAEA';
    final attend = _attendeeCountByEvent[event.id] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumbnail(image),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _metaRow(Icons.place_outlined, event.address),
                const SizedBox(height: 4),
                _metaRow(Icons.calendar_today_outlined, _formatDate(event.start)),
                const SizedBox(height: 4),
                _metaRow(
                  Icons.schedule,
                  '${_formatTime(event.start)} - ${_formatTime(event.end)}',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people, size: 15, color: _kGrey),
                    const SizedBox(width: 4),
                    Text(
                      '$attend',
                      style: const TextStyle(
                        color: _kAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        organizer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _kGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(EventImageModel? image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 100,
        height: 118,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _image(image),
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: _kPink,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: const Icon(Icons.bookmark, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(EventImageModel? image) {
    if (image == null) return _placeholderImage();
    final url = EventImageApiService.thumbnailUrl(image.imagePath);
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholderImage(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholderImage();
      },
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: const Color(0xFFEEEEEE),
      alignment: Alignment.center,
      child: const Icon(Icons.event, color: Color(0xFFBDBDBD), size: 32),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _kGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _kTextGrey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _errorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, color: Colors.grey, size: 40),
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(backgroundColor: _kAccent),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Text(
        'No saved events yet',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDate(DateTime d) =>
      '${d.year}/${_two(d.month)}/${_two(d.day)}';

  static String _formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
}