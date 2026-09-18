import 'package:flutter/material.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/HomePage/checkout_page.dart';
import 'package:ticket_com/models/category_models.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/orders_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';

const Color _kIndigo = Color(0xFF5B4DFF);
const Color _kLavender = Color(0xFFEFEEFC);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

/// Full event info page opened when a user taps an event card. Shows every
/// detail about the event and lets the signed-in user buy tickets: an order
/// is created and one ticket attendee row is added for every ticket quantity
/// selected.
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    this.image,
    this.organizer,
    this.attend = 0,
    this.saved = false,
    this.onToggleWish,
    this.minPrice,
    this.categories = const [],
  });

  final EventModel event;
  final EventImageModel? image;
  final EventOrganizer? organizer;
  final int attend;
  final bool saved;
  final Future<void> Function(EventModel event)? onToggleWish;
  final int? minPrice;
  final List<CategoryModel> categories;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _loading = true;
  bool _aboutExpanded = false;

  List<TicketTypeModel> _ticketTypes = [];
  List<PaymentType> _paymentTypes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final tickets = await _optional(
      () => TicketTypeApiService.getTicketTypesByEvent(widget.event.id),
      const <TicketTypeModel>[],
    );
    final paymentTypes = await _optional(
      OrdersApiService.getAllPaymentTypes,
      const <PaymentType>[],
    );

    if (!mounted) return;
    final sorted = List<TicketTypeModel>.of(tickets)
      ..sort((a, b) => a.priceInKip.compareTo(b.priceInKip));
    setState(() {
      _ticketTypes = sorted;
      _paymentTypes = paymentTypes;
      _loading = false;
    });
  }

  static Future<T> _optional<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }

  /// Price shown on the buy button: the cheapest available ticket (or FREE).
  String get _displayPrice {
    if (_ticketTypes.isNotEmpty) return _formatKip(_ticketTypes.first.priceInKip);
    final minPrice = widget.minPrice;
    if (minPrice != null && minPrice > 0) return _formatKip(minPrice);
    return 'FREE';
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
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.noTicketsAvailable)),
      );
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
          eventName: widget.event.name,
          ticketTypes: _ticketTypes,
          paymentTypes: _paymentTypes,
          session: session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kIndigo),
            )
          : Stack(
              children: [
                ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _heroWithPill(context),
                    _body(context),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12 + MediaQuery.paddingOf(context).bottom,
                  child: _buyBar(context),
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
          Positioned(
            top: topPad + 12,
            right: 12,
            child: _saveButton(),
          ),
        ],
      ),
    );
  }

  Widget _heroImage() {
    final image = widget.image;
    if (image == null) return _placeholderImage();
    return Image.network(
      EventImageApiService.fullImageUrl(image.imagePath),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: size),
      ),
    );
  }

  Widget _saveButton() {
    final saved = widget.saved;
    return GestureDetector(
      onTap: () => widget.onToggleWish?.call(widget.event),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_border,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // ---------------- going pill ----------------

  Widget _heroWithPill(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _hero(context),
        Positioned(
          left: 20,
          right: 20,
          bottom: -4,
          child: _goingPill(context),
        ),
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
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 18,
                ),
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
          const SizedBox(height: 26),
          _aboutSection(context),
          if (_ticketTypes.isNotEmpty) ...[
            const SizedBox(height: 24),
            _ticketsSection(context),
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
          const Icon(Icons.calendar_today_outlined,
              color: _kIndigo, size: 20),
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
          const Icon(Icons.location_on_outlined,
              color: _kIndigo, size: 20),
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
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${l10n.follow} "$name"'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _kLavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l10n.follow,
              style: const TextStyle(
                color: _kIndigo,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
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
      style: const TextStyle(
        color: _kTextGrey,
        fontSize: 14,
        height: 1.55,
      ),
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

  // ---------------- tickets ----------------

  /// Informational list of ticket types and prices. The actual ticket
  /// selection happens inside the checkout flow.
  Widget _ticketsSection(BuildContext context) {
    final l10n = l10nOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tickets,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (_ticketTypes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noTicketsAvailable,
              style: const TextStyle(color: _kTextGrey),
            ),
          )
        else
          for (var i = 0; i < _ticketTypes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ticketRow(_ticketTypes[i]),
          ],
      ],
    );
  }

  Widget _ticketRow(TicketTypeModel ticket) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _kLavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.typeName,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatKip(ticket.priceInKip),
                  style: const TextStyle(
                    color: _kIndigo,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- buy button ----------------

  Widget _buyBar(BuildContext context) {
    final l10n = l10nOf(context);
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
                  '${l10n.buyTicket.toUpperCase()} $_displayPrice',
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

  // ---------------- formatting ----------------

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDatePrimary(DateTime d) =>
      '${d.day} ${_months[d.month - 1]}, ${d.year}';

  static String _formatDateSecondary(DateTime start, DateTime end) =>
      '${_weekdays[start.weekday - 1]}, ${_formatTime(start)} - ${_formatTime(end)}';

  static String _formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String _formatKip(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final remaining = s.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buf.write(',');
    }
    return '$buf KIP';
  }
}