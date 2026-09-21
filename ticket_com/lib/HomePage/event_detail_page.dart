import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/HomePage/checkout_page.dart';
import 'package:ticket_com/HomePage/my_ticket_page.dart';
import 'package:ticket_com/models/category_models.dart';
import 'package:ticket_com/models/sponser_models.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/follow_api_service.dart';
import 'package:ticket_com/services/sponser_api_service.dart';
import 'package:ticket_com/services/orders_api_service.dart';
import 'package:ticket_com/services/ticket_attendence_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';
import 'package:ticket_com/utils/category_icons.dart';

const Color _kIndigo = Color(0xFF5B4DFF);
const Color _kLavender = Color(0xFFEFEEFC);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const double _kPinnedOffset = 60;

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    this.image,
    this.organizer,
    this.attend = 0,
    this.saved = false,
    this.onToggleWish,
    this.followed = false,
    this.onToggleFollow,
    this.minPrice,
    this.categories = const [],
  });

  final EventModel event;
  final EventImageModel? image;
  final EventOrganizer? organizer;
  final int attend;
  final bool saved;
  final Future<void> Function(EventModel event)? onToggleWish;
  final bool followed;
  final Future<void> Function(EventOrganizer organizer)? onToggleFollow;
  final int? minPrice;
  final List<CategoryModel> categories;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _loading = true;
  bool _aboutExpanded = false;
  bool _pinned = false;
  late bool _saved;

  List<TicketTypeModel> _ticketTypes = [];
  List<PaymentType> _paymentTypes = [];
  List<EventImageModel> _heroImages = [];
  List<TicketPurchase> _purchases = [];
  List<SponserModel> _sponsors = [];
  final PageController _heroController = PageController();
  final ScrollController _scrollController = ScrollController();
  Timer? _carouselTimer;
  int _currentImage = 0;
  late bool _following;

  @override
  void initState() {
    super.initState();
    _following = widget.followed;
    _saved = widget.saved;
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _heroController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pinned =
        _scrollController.hasClients && _scrollController.offset > _kPinnedOffset;
    if (pinned != _pinned) setState(() => _pinned = pinned);
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_heroController.hasClients) return;
      final next = (_currentImage + 1) % _heroImages.length;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
  }

  List<EventImageModel> get _viewerImages {
    if (_heroImages.isNotEmpty) return _heroImages;
    final image = widget.image;
    if (image == null) return const [];
    return [image];
  }

  void _openImageViewer(int initialIndex) {
    final images = _viewerImages;
    if (images.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _ImageViewerPage(images: images, initialIndex: initialIndex),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _heroImages = [];
      _currentImage = 0;
    });

    final tickets = await _optional(
      () => TicketTypeApiService.getTicketTypesByEvent(widget.event.id),
      const <TicketTypeModel>[],
    );
    final paymentTypes = await _optional(
      OrdersApiService.getAllPaymentTypes,
      const <PaymentType>[],
    );
    final images = await _optional(
      EventImageApiService.getAllEventImages,
      const <EventImageModel>[],
    );
    final heroImages =
        images.where((img) => img.eventId == widget.event.id).toList()
          ..sort((a, b) {
            if (a.isThumbnail != b.isThumbnail) {
              return a.isThumbnail ? -1 : 1;
            }
            return a.id.compareTo(b.id);
          });

    final sorted = List<TicketTypeModel>.of(tickets)
      ..sort((a, b) => a.priceInKip.compareTo(b.priceInKip));
    final purchases = await _loadPurchases(sorted);
    final sponsors = await _loadSponsors();

    if (!mounted) return;
    setState(() {
      _ticketTypes = sorted;
      _paymentTypes = paymentTypes;
      _purchases = purchases;
      _sponsors = sponsors;
      if (heroImages.isNotEmpty) _heroImages = heroImages;
      _loading = false;
    });
    if (heroImages.length > 1) _startCarousel();
  }

  /// Fetches every event<->sponsor link plus sponsor records, keeping only
  /// the sponsors linked to this event (the backend has no per-event query).
  Future<List<SponserModel>> _loadSponsors() async {
    final links = await _optional(
      SponserApiService.getAllEventSponsers,
      const <EventSponserModel>[],
    );
    final matchingIds = <int>{
      for (final link in links)
        if (link.eventId == widget.event.id) link.sponserId,
    };
    if (matchingIds.isEmpty) return const [];
    final sponsors = await _optional(
      SponserApiService.getAllSponsers,
      const <SponserModel>[],
    );
    return sponsors.where((s) => matchingIds.contains(s.id)).toList();
  }

  /// Fetches the signed-in user's orders and filters out the tickets they
  /// already bought for this event, so the page can show purchase info
  /// instead of the buy/payment bar.
  Future<List<TicketPurchase>> _loadPurchases(
    List<TicketTypeModel> eventTicketTypes,
  ) async {
    final session = AuthService.currentSession;
    if (session == null || eventTicketTypes.isEmpty) return const [];

    final byId = {for (final t in eventTicketTypes) t.id: t};

    final orders = await _optional(
      () => OrdersApiService.getOrdersByAccount(session.accountId),
      const <OrderModel>[],
    );

    final result = <TicketPurchase>[];
    for (final order in orders) {
      final attendees = await _optional(
        () => TicketAttendenceApiService.getTicketAttendeesByOrder(order.id),
        const <TicketAttendeeModel>[],
      );
      for (final attendee in attendees) {
        final ticketType = byId[attendee.ticketTypeId];
        if (ticketType == null) continue;
        result.add(
          TicketPurchase(
            ticketType: ticketType,
            attendee: attendee,
            order: order,
          ),
        );
      }
    }
    return result;
  }

  static Future<T> _optional<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _buy() async {
    final session = AuthService.currentSession;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = l10nOf(context);

    if (session == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.pleaseLogInToBuy)));
      return;
    }
    if (_ticketTypes.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noTicketsAvailable)));
      return;
    }
    if (_paymentTypes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No payment method available')),
      );
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          eventId: widget.event.id,
          eventName: widget.event.name,
          ticketTypes: _ticketTypes,
          paymentTypes: _paymentTypes,
          session: session,
          onePerPerson: widget.event.onePerPerson,
        ),
      ),
    );

    if (mounted) {
      final purchases = await _loadPurchases(_ticketTypes);
      if (!mounted) return;
      setState(() => _purchases = purchases);
    }
  }

  Future<void> _toggleSave() async {
    final messenger = ScaffoldMessenger.of(context);
    final callback = widget.onToggleWish;
    if (callback == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update wish list')),
      );
      return;
    }
    if (AuthService.currentSession == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please log in to save events')),
      );
      return;
    }

    final wasSaved = _saved;
    setState(() => _saved = !_saved);
    try {
      await callback(widget.event);
    } catch (_) {
      if (mounted) {
        setState(() => _saved = wasSaved);
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not update wish list')),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    final session = AuthService.currentSession;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = l10nOf(context);
    final organizer = widget.organizer;
    if (organizer == null) return;

    if (session == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please log in to follow organizers')),
      );
      return;
    }

    final wasFollowing = _following;
    setState(() => _following = !_following);
    try {
      if (wasFollowing) {
        await FollowApiService.deleteFollow(
          accountId: session.accountId,
          organizerId: organizer.id,
        );
      } else {
        await FollowApiService.createFollow(
          accountId: session.accountId,
          organizerId: organizer.id,
        );
      }
      await widget.onToggleFollow?.call(organizer);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              wasFollowing
                  ? l10n.unfollowedOrganizer
                  : l10n.followedOrganizer,
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _following = wasFollowing);
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not update follow')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kIndigo))
          : Stack(
              children: [
                ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [_heroWithPill(context), _body(context)],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12 + MediaQuery.paddingOf(context).bottom,
                  child: _buyBar(context),
                ),
                if (_pinned)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _topBar(context),
                  ),
              ],
            ),
    );
  }

  // ---------------- hero ----------------

  Widget _hero(BuildContext context) {
    final l10n = l10nOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.42)
        .clamp(280.0, 400.0)
        .toDouble();

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _heroImage(),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.28),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.42),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 12,
            left: 8,
            child: Row(
              children: [
                _circleIconButton(
                  icon: Icons.arrow_back_ios_new,
                  size: 18,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.eventDetails,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Positioned(top: topPad + 12, right: 12, child: _saveButton()),
        ],
      ),
    );
  }

  Widget _heroImage() {
    if (_heroImages.length > 1) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            onPointerDown: (_) => _stopCarousel(),
            onPointerUp: (_) => _startCarousel(),
            child: PageView.builder(
              controller: _heroController,
              itemCount: _heroImages.length,
              onPageChanged: (index) => setState(() => _currentImage = index),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openImageViewer(index),
                child: _networkImage(
                  EventImageApiService.fullImageUrl(
                    _heroImages[index].imagePath,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _heroImages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentImage ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _currentImage ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    final image = widget.image;
    if (image == null) return _placeholderImage();
    return GestureDetector(
      onTap: () => _openImageViewer(0),
      child: _networkImage(EventImageApiService.fullImageUrl(image.imagePath)),
    );
  }

  Widget _networkImage(String url) {
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
      color: const Color(0xFFE6E4F7),
      alignment: Alignment.center,
      child: const Icon(Icons.event, color: Color(0xFFB7B1E8), size: 64),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 18,
    Color iconColor = Colors.white,
    bool pinned = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: pinned ? Colors.white : Colors.black26,
          shape: BoxShape.circle,
          boxShadow: pinned
              ? const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: pinned ? _kTextDark : iconColor,
          size: size,
        ),
      ),
    );
  }

  Widget _saveButton({bool pinned = false}) {
    return GestureDetector(
      onTap: _toggleSave,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: pinned ? Colors.white : Colors.black26,
          borderRadius: BorderRadius.circular(10),
          boxShadow: pinned
              ? const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          _saved ? Icons.favorite : Icons.favorite_border,
          color: pinned
              ? (_saved ? Colors.redAccent : _kTextDark)
              : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// Sticky top bar shown while the hero scrolled off-screen: keeps only the
  /// back arrow and the heart icon reachable at all times.
  Widget _topBar(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(12, topPad + 4, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleIconButton(
            icon: Icons.arrow_back_ios_new,
            size: 18,
            onTap: () => Navigator.pop(context),
            pinned: true,
          ),
          _saveButton(pinned: true),
        ],
      ),
    );
  }

  // ---------------- going pill ----------------

  Widget _heroWithPill(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _hero(context),
        Positioned(left: 20, right: 20, bottom: -4, child: _goingPill(context)),
      ],
    );
  }

  Widget _goingPill(BuildContext context) {
    final l10n = l10nOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _avatarStack(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '+${widget.attend} ${l10n.going}',
              style: const TextStyle(
                color: _kIndigo,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite link shared'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _kIndigo,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                l10n.invite,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarStack() {
    return SizedBox(
      width: 74,
      height: 36,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: i * 22.0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kIndigo.withValues(alpha: 0.85 - (i * 0.12)),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- body ----------------

  Widget _body(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.name,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 22),
          _dateRow(context),
          const SizedBox(height: 16),
          _locationRow(context),
          const SizedBox(height: 16),
          _organizerRow(context),
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: 26),
            _categoriesSection(context),
          ],
          const SizedBox(height: 26),
          _aboutSection(context),
          if (_sponsors.isNotEmpty) ...[
            const SizedBox(height: 26),
            _sponsorsSection(context),
          ],
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _iconTile(Widget child) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _kLavender,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(child: child),
    );
  }

  Widget _twoLineText(String primary, String secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            secondary,
            style: const TextStyle(color: _kTextGrey, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _dateRow(BuildContext context) {
    final event = widget.event;
    return Row(
      children: [
        _iconTile(
          const Icon(Icons.calendar_today_outlined, color: _kIndigo, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _twoLineText(
            _formatDatePrimary(event.start),
            _formatDateSecondary(event.start, event.end),
          ),
        ),
      ],
    );
  }

  Widget _locationRow(BuildContext context) {
    return Row(
      children: [
        _iconTile(
          const Icon(Icons.location_on_outlined, color: _kIndigo, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: _twoLineText(widget.event.address, '')),
      ],
    );
  }

  Widget _organizerRow(BuildContext context) {
    final l10n = l10nOf(context);
    final organizer = widget.organizer;
    final name = organizer?.name ?? 'Organizer';
    final initial = name.isNotEmpty ? name.trim().characters.first : '?';

    Widget avatar;
    if (organizer?.logoPath != null && organizer!.logoPath!.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          EventImageApiService.fullImageUrl(organizer.logoPath!),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _organizerInitial(initial),
        ),
      );
    } else {
      avatar = _organizerInitial(initial);
    }

    return Row(
      children: [
        avatar,
        const SizedBox(width: 14),
        Expanded(child: _twoLineText(name, l10n.organizer)),
        GestureDetector(
          onTap: _toggleFollow,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _following ? _kIndigo : _kLavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_following) ...[
                  const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  _following ? l10n.following : l10n.follow,
                  style: TextStyle(
                    color: _following ? Colors.white : _kIndigo,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _organizerInitial(String initial) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kIndigo,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------- categories ----------------

  Widget _categoriesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10nOf(context).categories,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in widget.categories)
              _categoryChip(category),
          ],
        ),
      ],
    );
  }

  Widget _categoryChip(CategoryModel category) {
    final color = categoryColorFor(category.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconForKey(category.iconPath ?? ''),
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            category.name,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- sponsors ----------------

  Widget _sponsorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10nOf(context).eventsponsorinfo,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _sponsors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) => _sponsorItem(_sponsors[index]),
          ),
        ),
      ],
    );
  }

  Widget _sponsorItem(SponserModel sponsor) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _kLavender,
              shape: BoxShape.circle,
              border: Border.all(color: _kIndigo.withValues(alpha: 0.25)),
            ),
            child: sponsor.logoPath.isEmpty
                ? _sponsorInitial(sponsor)
                : Image.network(
                    SponserApiService.fullImageUrl(sponsor.logoPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _sponsorInitial(sponsor),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return _sponsorInitial(sponsor);
                    },
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            sponsor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _sponsorInitial(SponserModel sponsor) {
    final name = sponsor.name.trim();
    final initial = name.isEmpty ? 'S' : name.characters.first.toUpperCase();
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: _kIndigo,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------- about ----------------

  Widget _aboutSection(BuildContext context) {
    final l10n = l10nOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.aboutEvent,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _aboutText(),
        if (!_aboutExpanded)
          GestureDetector(
            onTap: () => setState(() => _aboutExpanded = true),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.readMore,
                style: const TextStyle(
                  color: _kIndigo,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Body copy with the tail fading out via a gradient mask, suggesting the
  /// truncated / "read more" affordance.
  Widget _aboutText() {
    final description = widget.event.description.isEmpty
        ? 'No description provided.'
        : widget.event.description;
    final text = Text(
      description,
      maxLines: 4,
      overflow: TextOverflow.clip,
      style: const TextStyle(color: _kTextGrey, fontSize: 14, height: 1.55),
    );
    if (_aboutExpanded) return text;
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: const [0.0, 0.55, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: text,
    );
  }

  // ---------------- buy button ----------------

  Widget _buyBar(BuildContext context) {
    final l10n = l10nOf(context);
    if (_purchases.isNotEmpty) return _purchasedBar(context);
    return Material(
      elevation: 8,
      shadowColor: _kIndigo.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(30),
      color: _kIndigo,
      child: InkWell(
        onTap: _buy,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  l10n.buyTicket.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(7),
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: _kIndigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- purchased bar ----------------

  Widget _purchasedBar(BuildContext context) {
    final l10n = l10nOf(context);
    final qtyByType = <int, int>{};
    for (final p in _purchases) {
      qtyByType[p.ticketType.id] = (qtyByType[p.ticketType.id] ?? 0) + 1;
    }
    final summary = <String>[
      for (final entry in qtyByType.entries)
        '${_ticketTypes.firstWhere((t) => t.id == entry.key).typeName}'
        ' ×${entry.value}',
    ];

    return Material(
      elevation: 8,
      shadowColor: const Color(0xFF2E9E5B).withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(30),
      color: const Color(0xFF2E9E5B),
      child: InkWell(
        onTap: _openTickets,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 18),
              const Icon(Icons.check_circle, color: Colors.white, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ticketPurchased,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      summary.join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(7),
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.confirmation_num_outlined,
                  color: Color(0xFF2E9E5B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  void _openTickets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyTicketPage(
          event: widget.event,
          purchases: _purchases,
          paymentTypes: _paymentTypes,
        ),
      ),
    );
  }

  // ---------------- formatting ----------------

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDatePrimary(DateTime d) =>
      '${d.day} ${_months[d.month - 1]}, ${d.year}';

  static String _formatDateSecondary(DateTime start, DateTime end) =>
      '${_weekdays[start.weekday - 1]}, ${_formatTime(start)} - ${_formatTime(end)}';

  static String _formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
}

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({required this.images, required this.initialIndex});

  final List<EventImageModel> images;
  final int initialIndex;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (context, index) => LayoutBuilder(
              builder: (context, constraints) => InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    EventImageApiService.fullImageUrl(
                      widget.images[index].imagePath,
                    ),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white70),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 12,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _current ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _current ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
