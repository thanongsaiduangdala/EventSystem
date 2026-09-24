import 'package:flutter/material.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/l10n/app_localizations.dart';
import 'package:ticket_com/services/attendee_response_api_service.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_question_api_service.dart';
import 'package:ticket_com/services/orders_api_service.dart';
import 'package:ticket_com/services/notification_service.dart';
import 'package:ticket_com/services/ticket_attendence_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';

const Color _kIndigo = Color(0xFF5B4DFF);
const Color _kLavender = Color(0xFFEFEEFC);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

// EventQuestionTypeID convention (matches eventquestiontype table):
//   1 = Text
//   2 = Checkbox   (multi-select, options come from EventQuestion.options)
//   3 = Radio box  (single-select, options come from EventQuestion.options)
//   4 = Text save as encrypted (plain text input; backend handles encryption)
//   5 = Yes or No  (single-select, fixed two-option list, no DB options)
//
// attendeeAnswer is always stored as plain text. For choice-type questions
// (2, 3, 5) it stores the 1-based index into the option list, comma-
// separated for checkboxes (e.g. "1,3").
const int _typeText = 1;
const int _typeCheckbox = 2;
const int _typeRadio = 3;
const int _typeEncryptedText = 4;
const int _typeYesNo = 5;

const List<String> _yesNoOptions = ['Yes', 'No'];

/// Checkout screen opened when a signed-in user taps "Buy Ticket" on an event.
/// Lets the buyer pick ticket types (e.g. Normal / 10km / 21km) and quantities,
/// choose a payment method, enter the proof-of-payment reference, and fill out
/// an attendee form for every ticket -- pre-filled from the signed-in account
/// when the ticket is "for me", blank when bought for someone else.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.ticketTypes,
    required this.paymentTypes,
    required this.session,
    this.onePerPerson = false,
  });

  final int eventId;
  final String eventName;
  final List<TicketTypeModel> ticketTypes;
  final List<PaymentType> paymentTypes;
  final UserSession session;
  final bool onePerPerson;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

/// Holds the buyer's answer to one event question for one attendee slot.
class _QuestionAnswer {
  _QuestionAnswer(this.question);

  final EventQuestionModel question;
  final TextEditingController textController = TextEditingController();
  final Set<int> checkbox = {}; // 1-based option indices, per response convention
  int? selected; // 1-based option index (radio / yes-no)
  bool error = false;

  void dispose() => textController.dispose();

  /// The answer string in the storage convention, or null/empty if unanswered.
  String? get value {
    switch (question.questionTypeId) {
      case _typeCheckbox:
        if (checkbox.isEmpty) return null;
        final sorted = checkbox.toList()..sort();
        return sorted.join(',');
      case _typeRadio:
      case _typeYesNo:
        return selected?.toString();
      default:
        final text = textController.text.trim();
        return text.isEmpty ? null : text;
    }
  }

  List<String> get options {
    if (question.questionTypeId == _typeYesNo) return _yesNoOptions;
    return question.options ?? const [];
  }
}

class _AttendeeSlot {
  _AttendeeSlot({required this.ticket});

  final TicketTypeModel ticket;
  bool forSelf = false;
  final fnController = TextEditingController();
  final lnController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final idController = TextEditingController();
  final answers = <_QuestionAnswer>[];
  bool fnError = false;
  bool lnError = false;
  bool phoneError = false;
  bool emailError = false;
  bool idError = false;

  /// Keeps the per-question answers in sync with the event's question list.
  void syncQuestions(List<EventQuestionModel> questions) {
    final ids = questions.map((q) => q.id).toSet();
    for (final a in List<_QuestionAnswer>.of(answers)) {
      if (!ids.contains(a.question.id)) {
        a.dispose();
        answers.remove(a);
      }
    }
    for (final q in questions) {
      if (!answers.any((a) => a.question.id == q.id)) {
        answers.add(_QuestionAnswer(q));
      }
    }
  }

  void dispose() {
    fnController.dispose();
    lnController.dispose();
    phoneController.dispose();
    emailController.dispose();
    idController.dispose();
    for (final a in answers) {
      a.dispose();
    }
  }
}

class _CheckoutPageState extends State<CheckoutPage> {
  late int _paymentTypeId;
  final Map<int, int> _qtyByType = {};
  List<_AttendeeSlot> _slots = [];
  List<EventQuestionModel> _questions = [];
  int _currentSlot = 0;
  final _proofController = TextEditingController();
  bool _proofError = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _paymentTypeId =
        widget.paymentTypes.isEmpty ? 0 : widget.paymentTypes.first.id;
    if (widget.ticketTypes.isNotEmpty) {
      _qtyByType[widget.ticketTypes.first.id] = 1;
    }
    _syncSlots();
    if (_slots.isNotEmpty) _fillSelf(_slots.first, true);
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (widget.eventId <= 0) return;
    List<EventQuestionModel> questions;
    try {
      questions = await EventQuestionApiService.getEventQuestionsByEvent(
        widget.eventId,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load event questions')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _questions = questions;
      for (final slot in _slots) {
        slot.syncQuestions(questions);
      }
    });
  }

  @override
  void dispose() {
    for (final slot in _slots) {
      slot.dispose();
    }
    _proofController.dispose();
    super.dispose();
  }

  List<(TicketTypeModel, int)> get _selections => [
    for (final t in widget.ticketTypes)
      if ((_qtyByType[t.id] ?? 0) > 0) (t, _qtyByType[t.id]!),
  ];

  int get _totalPrice {
    var total = 0;
    for (final (ticket, qty) in _selections) {
      total += ticket.priceInKip * qty;
    }
    return total;
  }

  void _setQty(TicketTypeModel ticket, int delta) {
    setState(() {
      final current = _qtyByType[ticket.id] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _qtyByType.remove(ticket.id);
      } else {
        _qtyByType[ticket.id] = next;
      }
      _syncSlots();
    });
  }

  /// Rebuilds the attendee forms to match the selected tickets, reusing
  /// existing forms for the same ticket type so entered data survives
  /// quantity changes.
  void _syncSlots() {
    final desired = <_AttendeeSlot>[];
    final used = <int>{};
    for (final (ticket, qty) in _selections) {
      for (var i = 0; i < qty; i++) {
        var reused = -1;
        for (var j = 0; j < _slots.length; j++) {
          if (!used.contains(j) && _slots[j].ticket.id == ticket.id) {
            reused = j;
            break;
          }
        }
        if (reused >= 0) {
          used.add(reused);
          desired.add(_slots[reused]);
        } else {
          desired.add(_AttendeeSlot(ticket: ticket));
        }
      }
    }
    final removed = <_AttendeeSlot>[];
    for (var j = 0; j < _slots.length; j++) {
      if (!used.contains(j)) removed.add(_slots[j]);
    }
    _slots = desired;
    for (final slot in _slots) {
      slot.syncQuestions(_questions);
    }
    if (_currentSlot >= _slots.length) {
      _currentSlot = _slots.isEmpty ? 0 : _slots.length - 1;
    }
    if (removed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final slot in removed) {
          slot.dispose();
        }
      });
    }
  }

  void _fillSelf(_AttendeeSlot slot, bool value) {
    setState(() {
      for (final s in _slots) {
        if (value && s != slot && s.forSelf) {
          s.forSelf = false;
          s.fnController.clear();
          s.lnController.clear();
          s.phoneController.clear();
          s.emailController.clear();
          s.idController.clear();
          s.fnError = false;
          s.lnError = false;
          s.phoneError = false;
          s.emailError = false;
          s.idError = false;
        }
      }
      slot.forSelf = value;
      if (value) {
        slot.fnController.text = widget.session.firstname;
        slot.lnController.text = widget.session.lastname;
        slot.phoneController.text = widget.session.phoneNum;
        slot.emailController.text = widget.session.email;
        slot.idController.clear();
        slot.fnError = false;
        slot.lnError = false;
        slot.phoneError = false;
        slot.emailError = false;
        slot.idError = false;
      } else {
        slot.fnController.clear();
        slot.lnController.clear();
        slot.phoneController.clear();
        slot.emailController.clear();
        slot.idController.clear();
      }
    });
  }

  static bool _isPhone(String s) => int.tryParse(s) != null;

  static bool _isEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  static String _formatApiDateTime(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}:00';

  static String _two(int value) => value.toString().padLeft(2, '0');

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

  bool _validate() {
    final proof = _proofController.text.trim();
    var valid = true;
    var firstBadSlot = -1;
    setState(() {
      _proofError = proof.isEmpty;
      if (_proofError) valid = false;
      final seenIds = <String>{};
      for (var s = 0; s < _slots.length; s++) {
        final slot = _slots[s];
        slot.fnError = slot.fnController.text.trim().isEmpty;
        slot.lnError = slot.lnController.text.trim().isEmpty;
        final phone = slot.phoneController.text.trim();
        slot.phoneError = phone.isEmpty || !_isPhone(phone);
        final email = slot.emailController.text.trim();
        slot.emailError = email.isEmpty || !_isEmail(email);
        final id = slot.idController.text.trim();
        final normalized = id.replaceAll(' ', '').toUpperCase();
        slot.idError = widget.onePerPerson &&
            (id.isEmpty || !seenIds.add(normalized));
        for (final a in slot.answers) {
          a.error = a.question.isRequire && (a.value?.isEmpty ?? true);
        }
        final hasQuestionError = slot.answers.any((a) => a.error);
        if (slot.fnError ||
            slot.lnError ||
            slot.phoneError ||
            slot.emailError ||
            slot.idError ||
            hasQuestionError) {
          valid = false;
          if (firstBadSlot < 0) firstBadSlot = s;
        }
      }
      if (firstBadSlot >= 0) _currentSlot = firstBadSlot;
    });
    return valid;
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = l10nOf(context);

    if (_selections.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.selectTicketFirst)));
      return;
    }
    if (!_validate()) return;

    setState(() => _submitting = true);
    try {
      final order = await OrdersApiService.createOrder(
        accountId: widget.session.accountId,
        paymentTypeId: _paymentTypeId,
        paymentDateYMDT: _formatApiDateTime(DateTime.now()),
        proveOfPayment: _proofController.text.trim(),
      );
      final orderId = int.tryParse(order['OrderID'].toString());
      if (orderId == null) {
        throw Exception('Order id missing in response');
      }

      for (final slot in _slots) {
        final attendeeJson =
            await TicketAttendenceApiService.createTicketAttendee(
              ticketTypeId: slot.ticket.id,
              orderId: orderId,
              firstName: slot.fnController.text.trim(),
              lastName: slot.lnController.text.trim(),
              phoneNum: slot.phoneController.text.trim(),
              email: slot.emailController.text.trim(),
              nationalId: widget.onePerPerson
                  ? slot.idController.text.trim()
                  : null,
            );
        final attendeeId = int.tryParse(
          attendeeJson['attendeeID'].toString(),
        );
        for (final a in slot.answers) {
          final value = a.value;
          if (value == null || value.isEmpty || attendeeId == null) continue;
          await AttendeeResponseApiService.createAttendeeResponse(
            eventQuestionId: a.question.id,
            attendeeId: attendeeId,
            attendeeAnswer: value,
          );
        }
      }

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.orderPlaced)));
      NotificationService.instance.refresh(force: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e.toString();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message.toLowerCase().contains('already') ||
                    message.contains('409')
                ? l10n.nationalIdAlreadyUsed
                : 'Error: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: Text(
          l10n.checkout,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _ticketSelectionSection(l10n),
          const SizedBox(height: 20),
          _orderSummary(l10n),
          const SizedBox(height: 20),
          _paymentSection(l10n),
          if (_slots.isNotEmpty) ...[
            const SizedBox(height: 20),
            _attendeesSection(l10n),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: _confirmButton(l10n),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _kTextDark,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ---------------- ticket selection ----------------

  Widget _ticketSelectionSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.tickets),
        const SizedBox(height: 10),
        if (widget.ticketTypes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noTicketsAvailable,
              style: const TextStyle(color: _kTextGrey),
            ),
          )
        else
          for (var i = 0; i < widget.ticketTypes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ticketRow(widget.ticketTypes[i]),
          ],
      ],
    );
  }

  Widget _ticketRow(TicketTypeModel ticket) {
    final qty = _qtyByType[ticket.id] ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
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
          _qtyStepper(ticket, qty),
        ],
      ),
    );
  }

  Widget _qtyStepper(TicketTypeModel ticket, int qty) {
    final borderColor = qty > 0 ? _kIndigo : const Color(0xFFD5D2EC);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: qty > 0 ? 1.4 : 1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _submitting ? null : () => _setQty(ticket, -1),
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.remove, size: 16, color: _kIndigo),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kTextDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          InkWell(
            onTap: _submitting ? null : () => _setQty(ticket, 1),
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.add, size: 16, color: _kIndigo),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- order summary ----------------

  Widget _orderSummary(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.orderSummary),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kLavender,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.eventName,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (_selections.isEmpty)
                Text(
                  l10n.selectTicketFirst,
                  style: const TextStyle(color: _kTextGrey, fontSize: 14),
                )
              else
                for (final (ticket, qty) in _selections) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${ticket.typeName}  ×$qty',
                          style: const TextStyle(
                            color: _kTextDark,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _formatKip(ticket.priceInKip * qty),
                        style: const TextStyle(
                          color: _kTextDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              const Divider(color: Color(0xFFD5D2EC), height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.total,
                    style: const TextStyle(
                      color: _kTextDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _formatKip(_totalPrice),
                    style: const TextStyle(
                      color: _kIndigo,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- payment ----------------

  Widget _paymentSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.paymentMethod),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _paymentTypeId,
          decoration: _fieldDecoration(),
          items: [
            for (final p in widget.paymentTypes)
              DropdownMenuItem(value: p.id, child: Text(p.paymentTypeName)),
          ],
          onChanged: _submitting
              ? null
              : (value) {
                  if (value != null) setState(() => _paymentTypeId = value);
                },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _proofController,
          enabled: !_submitting,
          keyboardType: TextInputType.text,
          decoration: _fieldDecoration(
            label: l10n.paymentProof,
            hint: l10n.paymentProofHint,
            error: _proofError ? l10n.dontLeavePaymentProofEmpty : null,
          ).copyWith(
            prefixIcon: const Icon(Icons.receipt_long, color: _kTextGrey),
          ),
          onChanged: (_) {
            if (_proofError) setState(() => _proofError = false);
          },
        ),
      ],
    );
  }

  // ---------------- attendees ----------------

  Widget _attendeesSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.attendeeInfo),
        if (widget.onePerPerson) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: _kLavender,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kIndigo.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.badge_outlined,
                    color: _kIndigo, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.oneTicketPerPersonInfo,
                    style: const TextStyle(
                      color: _kTextGrey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (_slots.length > 1) ...[
          _attendeeTabs(l10n),
          const SizedBox(height: 10),
        ],
        _attendeeCard(l10n, _currentSlot, _slots[_currentSlot]),
      ],
    );
  }

  /// Horizontal tab bar -- one chip per attendee slot, so the attendee forms
  /// don't stack into a long scroll. Shows an error dot on chips whose form
  /// currently fails validation.
  Widget _attendeeTabs(AppLocalizations l10n) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _slots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final slot = _slots[i];
          final selected = i == _currentSlot;
          final hasError = slot.fnError ||
              slot.lnError ||
              slot.phoneError ||
              slot.emailError ||
              slot.idError ||
              slot.answers.any((a) => a.error);
          return GestureDetector(
            onTap: () => setState(() => _currentSlot = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _kIndigo : _kLavender,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l10n.person} ${i + 1}',
                    style: TextStyle(
                      color: selected ? Colors.white : _kTextDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.error,
                      size: 14,
                      color: selected ? Colors.white : Colors.redAccent,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _attendeeCard(AppLocalizations l10n, int index, _AttendeeSlot slot) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0DCFD), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: slot.forSelf,
            onChanged: _submitting
                ? null
                : (value) => _fillSelf(slot, value),
            activeTrackColor: _kIndigo,
            title: Text(l10n.forYourself,
                style: const TextStyle(color: _kTextDark, fontSize: 14)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          Text(
            l10n.ticketSlot('${index + 1}', slot.ticket.typeName),
            style: const TextStyle(
              color: _kTextGrey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _nameRow(l10n, slot),
          const SizedBox(height: 10),
          TextField(
            controller: slot.phoneController,
            enabled: !_submitting && !slot.forSelf,
            keyboardType: TextInputType.phone,
            decoration: _fieldDecoration(
              label: l10n.phoneNumber,
              error: slot.phoneError
                  ? slot.phoneController.text.trim().isEmpty
                        ? l10n.dontLeavePhoneEmpty
                        : l10n.phoneMustBeNumbers
                  : null,
            ),
            onChanged: (_) {
              if (slot.phoneError) setState(() => slot.phoneError = false);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: slot.emailController,
            enabled: !_submitting && !slot.forSelf,
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecoration(
              label: l10n.email,
              error: slot.emailError
                  ? slot.emailController.text.trim().isEmpty
                        ? l10n.dontLeaveEmailEmpt
                        : l10n.pleaseEnterValidEmail
                  : null,
            ),
            onChanged: (_) {
              if (slot.emailError) setState(() => slot.emailError = false);
            },
          ),
          if (widget.onePerPerson) ...[
            const SizedBox(height: 10),
            TextField(
              controller: slot.idController,
              enabled: !_submitting,
              keyboardType: TextInputType.text,
              decoration: _fieldDecoration(
                label: l10n.nationalId,
                hint: l10n.nationalIdHint,
                error: slot.idError
                    ? slot.idController.text.trim().isEmpty
                          ? l10n.nationalIdRequired
                          : l10n.nationalIdRepeated
                    : null,
              ).copyWith(
                prefixIcon: const Icon(Icons.badge_outlined,
                    color: _kTextGrey),
              ),
              onChanged: (_) {
                if (slot.idError) setState(() => slot.idError = false);
              },
            ),
          ],
          if (slot.answers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFE0DCFD), height: 1),
            const SizedBox(height: 12),
            for (final a in slot.answers) ...[
              _questionWidget(l10n, slot, a),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _questionWidget(
    AppLocalizations l10n,
    _AttendeeSlot slot,
    _QuestionAnswer a,
  ) {
    final options = a.options;
    Widget input;
    switch (a.question.questionTypeId) {
      case _typeCheckbox:
        input = options.isEmpty
            ? _textAnswerField(l10n, slot, a)
            : Column(
                children: [
                  for (var i = 0; i < options.length; i++)
                    CheckboxListTile(
                      value: a.checkbox.contains(i + 1),
                      onChanged: _submitting
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  a.checkbox.add(i + 1);
                                } else {
                                  a.checkbox.remove(i + 1);
                                }
                                a.error = false;
                              });
                            },
                      activeColor: _kIndigo,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        options[i],
                        style: const TextStyle(
                          color: _kTextDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              );
      case _typeRadio:
      case _typeYesNo:
        input = options.isEmpty
            ? _textAnswerField(l10n, slot, a)
            : Column(
                children: [
                  for (var i = 0; i < options.length; i++)
                    RadioListTile<int>(
                      value: i + 1,
                      groupValue: a.selected,
                      onChanged: _submitting
                          ? null
                          : (v) {
                              setState(() {
                                a.selected = v;
                                a.error = false;
                              });
                            },
                      activeColor: _kIndigo,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        options[i],
                        style: const TextStyle(
                          color: _kTextDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              );
      case _typeText:
      case _typeEncryptedText:
        input = _textAnswerField(l10n, slot, a);
      default:
        input = _textAnswerField(l10n, slot, a);
    }

    final choiceType = a.question.questionTypeId == _typeCheckbox ||
        a.question.questionTypeId == _typeRadio ||
        a.question.questionTypeId == _typeYesNo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.question.isRequire
              ? '${a.question.question} *'
              : a.question.question,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        input,
        if (a.error && choiceType)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.questionRequired,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _textAnswerField(
    AppLocalizations l10n,
    _AttendeeSlot slot,
    _QuestionAnswer a,
  ) {
    return TextField(
      controller: a.textController,
      enabled: !_submitting,
      maxLines: 2,
      decoration: _fieldDecoration(
        label: l10n.answerLabel,
        error: a.error ? l10n.questionRequired : null,
      ),
      onChanged: (_) {
        if (a.error) setState(() => a.error = false);
      },
    );
  }

  Widget _nameRow(AppLocalizations l10n, _AttendeeSlot slot) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: slot.fnController,
            enabled: !_submitting && !slot.forSelf,
            decoration: _fieldDecoration(
              label: l10n.firstName,
              error: slot.fnError ? l10n.dontLeaveFirstNameEmpty : null,
            ),
            onChanged: (_) {
              if (slot.fnError) setState(() => slot.fnError = false);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: slot.lnController,
            enabled: !_submitting && !slot.forSelf,
            decoration: _fieldDecoration(
              label: l10n.lastName,
              error: slot.lnError ? l10n.dontLeaveLastNameEmpty : null,
            ),
            onChanged: (_) {
              if (slot.lnError) setState(() => slot.lnError = false);
            },
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    String? error,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      filled: true,
      fillColor: _kLavender,
      labelStyle: const TextStyle(color: _kTextGrey),
      hintStyle: const TextStyle(color: _kTextGrey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kIndigo, width: 1.6),
      ),
    );
  }

  Widget _confirmButton(AppLocalizations l10n) {
    return Material(
      elevation: 8,
      shadowColor: _kIndigo.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(30),
      color: _kIndigo,
      child: InkWell(
        onTap: _submitting ? null : _submit,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: _submitting
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Text(
                        '${l10n.confirmOrder.toUpperCase()}  ${_formatKip(_totalPrice)}',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}