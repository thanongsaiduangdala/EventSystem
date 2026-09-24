import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/HomePage/event_detail_page.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/event_organizer_api_service.dart'
    show EventOrganizerApiService;
import 'package:ticket_com/services/follow_api_service.dart';
import 'package:ticket_com/services/wishlist_api_service.dart';

const Color _kAccent = Color(0xFF5B4DFF);
const Color _kPurpleDeep = Color(0xFF4A00E0);
const Color _kPurpleLight = Color(0xFF8E2DE2);
const Color _kPink = Color(0xFFEC407A);
const Color _kGrey = Color(0xFF9E9E9E);
const Color _kTextGrey = Color(0xFF757575);

class WishPanel extends StatefulWidget {
  const WishPanel({super.key, this.showBackButton = false});

  /// When pushed as a standalone route (e.g. from the Home drawer's "Wish"
  /// item), shows an AppBar with a back arrow. Stays hidden when used as a
  /// bottom-navigation tab.
  final bool showBackButton;

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
  final Map<int, int> _wishIdByEvent = {};
  List<EventOrganizer> _followedOrganizers = [];
  final Set<int> _unfollowingOrganizers = {};
  bool _showFollowed = false;

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
      _wishIdByEvent.clear();
      for (final w in wishes) {
        attendeeCount[w.eventId] = (attendeeCount[w.eventId] ?? 0) + 1;
        if (session != null && w.accountId == session.accountId) {
          myEventIds.add(w.eventId);
          _wishIdByEvent[w.eventId] = w.id;
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
      final follows = await _optional(
        FollowApiService.getAllFollows,
        const <FollowModel>[],
      );

      final imageByEvent = <int, EventImageModel>{};
      for (final img in images) {
        if (img.isThumbnail || !imageByEvent.containsKey(img.eventId)) {
          imageByEvent[img.eventId] = img;
        }
      }

      final followedIds = <int>{};
      if (session != null) {
        for (final f in follows) {
          if (f.accountId == session.accountId) {
            followedIds.add(f.organizerId);
          }
        }
      }
      final followedOrganizers =
          organizers.where((o) => followedIds.contains(o.id)).toList();

      if (!mounted) return;
      setState(() {
        _events = events;
        _imageByEvent = imageByEvent;
        _organizerById = {for (final o in organizers) o.id: o};
        _attendeeCountByEvent = attendeeCount;
        _followedOrganizers = followedOrganizers;
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

  void _openEventDetail(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailPage(
          event: event,
          image: _imageByEvent[event.id],
          organizer: _organizerById[event.organizerId],
          attend: _attendeeCountByEvent[event.id] ?? 0,
          saved: _wishIdByEvent.containsKey(event.id),
          onToggleWish: _toggleWish,
        ),
      ),
    );
  }

  Future<void> _toggleWish(EventModel event) async {
    final messenger = ScaffoldMessenger.of(context);
    final session = AuthService.currentSession;
    if (session == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in to save events')),
      );
      return;
    }

    final wishId = _wishIdByEvent[event.id];
    if (wishId != null) {
      await _optional(() => WishlistApiService.deleteWishById(wishId), null);
    } else {
      await _optional(
        () => WishlistApiService.createWish(
          accountId: session.accountId,
          eventId: event.id,
        ),
        null,
      );
    }
    await _load();
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
          child: _loading && _events.isEmpty && _followedOrganizers.isEmpty
              ? _loadingView()
              : _body(context),
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
        _header(context, topPad),
        const SizedBox(height: 16),
        if (_showFollowed)
          _followedContent(context)
        else ...[
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
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _header(BuildContext context, double topPad) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPurpleLight, _kPurpleDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        16, topPad + (widget.showBackButton ? 8 : 0) + 14, 16, 20),
      child: Column(
        children: [
          Row(
            children: [
              if (widget.showBackButton) ...[
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  l10nOf(context).wish,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _toggle(context),
        ],
      ),
    );
  }

  Widget _toggle(BuildContext context) {
    final l10n = l10nOf(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleItem(l10n.wish, false)),
          Expanded(
            child: _toggleItem(l10n.followedOrganizers, true),
          ),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool followed) {
    final active = _showFollowed == followed;
    return GestureDetector(
      onTap: () => setState(() => _showFollowed = followed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? _kPurpleDeep : Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _followedContent(BuildContext context) {
    final l10n = l10nOf(context);
    if (_followedOrganizers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Icon(Icons.favorite_border, color: _kGrey, size: 36),
              const SizedBox(height: 10),
              Text(
                'You\'re not following any organizers yet',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kTextGrey, fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: _kAccent),
                child: const Text(
                  'Refresh',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${l10n.followedOrganizers} (${_followedOrganizers.length})',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._followedOrganizers.map(
          (o) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _organizerCard(o),
          ),
        ),
      ],
    );
  }

  Widget _organizerCard(EventOrganizer organizer) {
    final name = organizer.name.trim();
    final summary = organizer.description?.trim().isNotEmpty == true
        ? organizer.description!.trim()
        : null;
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final removing = _unfollowingOrganizers.contains(organizer.id);
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          _organizerAvatar(organizer, initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (summary != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kTextGrey,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (removing)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kAccent,
              ),
            )
          else
            GestureDetector(
              onTap: () => _unfollowOrganizer(organizer),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E6FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, color: _kAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      l10nOf(context).following,
                      style: const TextStyle(
                        color: _kAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _unfollowOrganizer(EventOrganizer organizer) async {
    final session = AuthService.currentSession;
    final l10n = l10nOf(context);
    if (session == null) return;
    setState(() => _unfollowingOrganizers.add(organizer.id));
    try {
      await FollowApiService.deleteFollow(
        accountId: session.accountId,
        organizerId: organizer.id,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unfollowedOrganizer)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _unfollowingOrganizers.remove(organizer.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrongPleaseTryAgain)),
      );
    }
  }

  Widget _organizerAvatar(EventOrganizer organizer, String initial) {
    final logo = organizer.logoPath;
    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          EventOrganizerApiService.fullImageUrl(logo),
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _organizerInitial(initial),
        ),
      );
    }
    return _organizerInitial(initial);
  }

  Widget _organizerInitial(String initial) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: _kAccent,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _wishCard(EventModel event) {
    final image = _imageByEvent[event.id];
    final organizer = _organizerById[event.organizerId]?.name ?? 'GAEA';
    final attend = _attendeeCountByEvent[event.id] ?? 0;

    return GestureDetector(
      onTap: () => _openEventDetail(event),
      child: Container(
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