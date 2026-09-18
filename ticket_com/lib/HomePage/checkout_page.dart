import 'package:flutter/material.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/l10n/app_localizations.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/orders_api_service.dart';
import 'package:ticket_com/services/ticket_attendence_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';

const Color _kIndigo = Color(0xFF5B4DFF);
const Color _kLavender = Color(0xFFEFEEFC);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

/// Checkout screen opened when a signed-in user taps "Buy Ticket" on an event.
/// Lets the buyer pick ticket types (e.g. Normal / 10km / 21km) and quantities,
/// choose a payment method, enter the proof-of-payment reference, and fill out
/// an attendee form for every ticket -- pre-filled from the signed-in account
/// when the ticket is "for me", blank when bought for someone else.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.eventName,
    required this.ticketTypes,
    required this.paymentTypes,
    required this.session,
  });

  final String eventName;
  final List<TicketTypeModel> ticketTypes;
  final List<PaymentType> paymentTypes;
  final UserSession session;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _AttendeeSlot {
  _AttendeeSlot({required this.ticket});

  final TicketTypeModel ticket;
  bool forSelf = false;
  final fnController = TextEditingController();
  final lnController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  bool fnError = false;
  bool lnError = false;
  bool phoneError = false;
  bool emailError = false;

  void dispose() {
    fnController.dispose();
    lnController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }
}

class _CheckoutPageState extends State<CheckoutPage> {
  late int _paymentTypeId;
  final Map<int, int> _qtyByType = {};
  List<_AttendeeSlot> _slots = [];
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
      slot.forSelf = value;
      if (value) {
        slot.fnController.text = widget.session.firstname;
        slot.lnController.text = widget.session.lastname;
        slot.phoneController.text = widget.session.phoneNum;
        slot.emailController.text = widget.session.email;
        slot.fnError = false;
        slot.lnError = false;
        slot.phoneError = false;
        slot.emailError = false;
      } else {
        slot.fnController.clear();
        slot.lnController.clear();
        slot.phoneController.clear();
        slot.emailController.clear();
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
    setState(() {
      _proofError = proof.isEmpty;
      if (_proofError) valid = false;
      for (final slot in _slots) {
        slot.fnError = slot.fnController.text.trim().isEmpty;
        slot.lnError = slot.lnController.text.trim().isEmpty;
        final phone = slot.phoneController.text.trim();
        slot.phoneError = phone.isEmpty || !_isPhone(phone);
        final email = slot.emailController.text.trim();
        slot.emailError = email.isEmpty || !_isEmail(email);
        if (slot.fnError ||
            slot.lnError ||
            slot.phoneError ||
            slot.emailError) {
          valid = false;
        }
      }
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
        await TicketAttendenceApiService.createTicketAttendee(
          ticketTypeId: slot.ticket.id,
          orderId: orderId,
          firstName: slot.fnController.text.trim(),
          lastName: slot.lnController.text.trim(),
          phoneNum: slot.phoneController.text.trim(),
          email: slot.emailController.text.trim(),
        );
      }

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.orderPlaced)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
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
        const SizedBox(height: 10),
        for (var i = 0; i < _slots.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _attendeeCard(l10n, i, _slots[i]),
        ],
      ],
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
        ],
      ),
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