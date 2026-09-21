import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/services/attendee_response_api_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_question_api_service.dart';
import 'package:ticket_com/services/orders_api_service.dart';
import 'package:ticket_com/services/ticket_attendence_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';

const Color _kIndigo = Color(0xFF5B4DFF);
const Color _kPurpleLight = Color(0xFF8E2DE2);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

// EventQuestionTypeID conventions (mirrors checkout_page.dart):
//   1 = Text, 2 = Checkbox, 3 = Radio box, 4 = Encrypted text, 5 = Yes or No.
// attendeeAnswer is plain text for 1/4 and 1-based option indices for 2/3/5
// (comma-separated for checkboxes).
const int _typeCheckbox = 2;
const int _typeRadio = 3;
const int _typeYesNo = 5;

const List<String> _yesNoOptions = ['Yes', 'No'];

/// One ticket the signed-in user bought, matching one attendee slot: the
/// ticket type, the person it was bought for, and the paying order.
class TicketPurchase {
  const TicketPurchase({
    required this.ticketType,
    required this.attendee,
    required this.order,
  });

  final TicketTypeModel ticketType;
  final TicketAttendeeModel attendee;
  final OrderModel order;
}

/// Full-screen view of the user's purchased tickets for an event. Each ticket
/// shows its own QR code (scanned at the entrance to check in), the attendee
/// details, and the answers given to the event questions.
class MyTicketPage extends StatefulWidget {
  const MyTicketPage({
    super.key,
    required this.event,
    required this.purchases,
    this.paymentTypes = const [],
  });

  final EventModel event;
  final List<TicketPurchase> purchases;
  final List<PaymentType> paymentTypes;

  @override
  State<MyTicketPage> createState() => _MyTicketPageState();
}

class _MyTicketPageState extends State<MyTicketPage> {
  bool _loading = true;
  List<EventQuestionModel> _questions = [];
  Map<int, List<AttendeeResponseModel>> _responsesByAttendee = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final questions = await _optional(
      () => EventQuestionApiService.getEventQuestionsByEvent(widget.event.id),
      const <EventQuestionModel>[],
    );

    final responses = <int, List<AttendeeResponseModel>>{};
    for (final p in widget.purchases) {
      responses[p.attendee.id] = await _optional(
        () => AttendeeResponseApiService.getResponsesByAttendee(
          p.attendee.id,
        ),
        const <AttendeeResponseModel>[],
      );
    }

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _responsesByAttendee = responses;
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

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _appBar(context),
        body: const Center(child: CircularProgressIndicator(color: _kIndigo)),
      );
    }

    if (widget.purchases.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _appBar(context),
        body: _emptyState(context),
      );
    }

    return DefaultTabController(
      length: widget.purchases.length,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _appBar(context, bottom: _ticketTabs()),
        body: TabBarView(
          children: [
            for (var i = 0; i < widget.purchases.length; i++)
              _ticketTabView(context, widget.purchases[i], i + 1),
          ],
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context, {Widget? bottom}) {
    final l10n = l10nOf(context);
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _kTextDark,
      elevation: 0,
      title: Text(
        l10n.myTickets,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      bottom: bottom == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(62),
              child: bottom,
            ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final l10n = l10nOf(context);
    return Center(
      child: Text(
        l10n.noTicketsYet,
        style: const TextStyle(color: _kTextGrey, fontSize: 14),
      ),
    );
  }

  /// Top navigation: one pill per purchased ticket, labelled with the ticket
  /// type name (with a number when the same type was bought more than once).
  /// Tapping a pill shows that ticket in the body below.
  Widget _ticketTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1EEFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          isScrollable: true,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 5,
                offset: Offset(0, 1),
              ),
            ],
          ),
          labelColor: _kIndigo,
          unselectedLabelColor: _kTextGrey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          tabs: [
            for (var i = 0; i < widget.purchases.length; i++)
              Tab(text: _tabLabel(widget.purchases[i], i + 1)),
          ],
        ),
      ),
    );
  }

  /// The first name of the person the ticket was bought for. "Alice 1",
  /// "Alice 2" when the same name appears more than once in this order.
  String _tabLabel(TicketPurchase p, int number) {
    final name = p.attendee.firstName;
    final sameName = widget.purchases
        .where((x) => x.attendee.firstName == name)
        .length;
    return sameName > 1 ? '$name $number' : name;
  }

  Widget _ticketTabView(BuildContext context, TicketPurchase p, int number) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [_ticketCard(context, p, number)],
    );
  }

  // ---------------- ticket card ----------------

  Widget _ticketCard(BuildContext context, TicketPurchase p, int number) {
    final l10n = l10nOf(context);
    final attendee = p.attendee;
    final order = p.order;
    final answers = _answersFor(attendee.id);
    final infoRows = <(String, String)>[
      (l10n.order, '#${order.id}'),
      (l10n.paymentMethod, _paymentName(order.paymentTypeId)),
      if (order.paymentDate != null)
        (l10n.paymentDate, _formatDatePrimary(order.paymentDate!)),
      (l10n.phoneNumber, attendee.phoneNum),
      (l10n.email, attendee.email),
      if (attendee.nationalId != null && attendee.nationalId!.isNotEmpty)
        (l10n.nationalId, attendee.nationalId!),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0DCFD), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ticketHeader(context, p, number),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: _perforation(),
          ),
          _qrSection(context, p),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
            child: _infoSection(context, infoRows),
          ),
          if (answers.isNotEmpty) ...[
            const SizedBox(height: 14),
            _answersSection(context, answers),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _ticketHeader(BuildContext context, TicketPurchase p, int number) {
    final l10n = l10nOf(context);
    final event = widget.event;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPurpleLight, _kIndigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Colors.white70,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _eventDate(event.start, event.end),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                color: Colors.white70,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.ticketSlot('$number', p.ticketType.typeName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatKip(p.ticketType.priceInKip),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A short dashed line with three "punch holes", mimicking the perforation
  /// on a paper ticket between the gradient header and the ticket body.
  Widget _perforation() {
    Widget hole() => Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFE0DCFD)),
        ),
      ),
    );

    return SizedBox(
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 7,
            child: Container(height: 2, color: const Color(0xFFE0DCFD)),
          ),
          Positioned(left: 14, child: hole()),
          Positioned(right: 14, child: hole()),
          hole(),
        ],
      ),
    );
  }

  Widget _qrSection(BuildContext context, TicketPurchase p) {
    final l10n = l10nOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Column(
        children: [
          Text(
            l10n.scanQrToEnter,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0DCFD), width: 1.4),
            ),
            child: QrImageView(
              data: _qrPayload(p),
              version: QrVersions.auto,
              size: 208,
              gapless: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(BuildContext context, List<(String, String)> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Text(
                  label,
                  style: const TextStyle(color: _kTextGrey, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _answersSection(
    BuildContext context,
    List<(EventQuestionModel, String)> answers,
  ) {
    final l10n = l10nOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz_outlined, color: _kIndigo, size: 18),
              const SizedBox(width: 8),
              Text(
                l10n.answers,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < answers.length; i++) ...[
            Text(
              answers[i].$1.question,
              style: const TextStyle(
                color: _kTextDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              answers[i].$2,
              style: const TextStyle(color: _kTextGrey, fontSize: 13),
            ),
            if (i < answers.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  // ---------------- data helpers ----------------

  String _qrPayload(TicketPurchase p) =>
      'TICKET:EV${widget.event.id}:O${p.order.id}:'
      'A${p.attendee.id}:T${p.ticketType.id}';

  String _paymentName(int paymentTypeId) {
    for (final p in widget.paymentTypes) {
      if (p.id == paymentTypeId) return p.paymentTypeName;
    }
    return '#$paymentTypeId';
  }

  List<(EventQuestionModel, String)> _answersFor(int attendeeId) {
    final responses = _responsesByAttendee[attendeeId] ?? const [];
    final qById = {for (final q in _questions) q.id: q};
    final result = <(EventQuestionModel, String)>[];
    for (final response in responses) {
      final question = qById[response.eventQuestionId];
      if (question == null) continue;
      result.add((question, _formatAnswer(question, response.attendeeAnswer)));
    }
    result.sort((a, b) => a.$1.sortOrder.compareTo(b.$1.sortOrder));
    return result;
  }

  /// Translates the stored answer convention (1-based option indices) back
  /// into the readable option text for the choice-type questions.
  static String _formatAnswer(EventQuestionModel q, String answer) {
    final options =
        q.questionTypeId == _typeYesNo ? _yesNoOptions : (q.options ?? const []);
    switch (q.questionTypeId) {
      case _typeCheckbox:
        final indices = answer
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();
        if (indices.isEmpty || options.isEmpty) return answer;
        return indices
            .map(
              (i) => (i >= 1 && i <= options.length)
                  ? options[i - 1]
                  : '$i',
            )
            .join(', ');
      case _typeRadio:
      case _typeYesNo:
        final index = int.tryParse(answer.trim());
        if (index != null && index >= 1 && index <= options.length) {
          return options[index - 1];
        }
        return answer;
      default:
        return answer;
    }
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

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDatePrimary(DateTime d) =>
      '${d.day} ${_months[d.month - 1]}, ${d.year}';

  static String _eventDate(DateTime start, DateTime end) {
    final date = '${start.day} ${_months[start.month - 1]}, ${start.year}';
    final time = '${_two(start.hour)}:${_two(start.minute)}'
        ' - ${_two(end.hour)}:${_two(end.minute)}';
    return '$date · $time';
  }

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