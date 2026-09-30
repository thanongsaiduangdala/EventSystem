import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/ticket_scanner_page.dart';
import 'package:ticket_com/services/attendee_response_api_service.dart';
import 'package:ticket_com/services/event_question_api_service.dart';
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kGreen = Color(0xFF43A047);
const Color _kRed = Color(0xFFE53935);

class TeamCheckInPage extends StatefulWidget {
  const TeamCheckInPage({
    super.key,
    required this.membership,
    required this.eventId,
    required this.eventName,
    this.canRevoke = false,
    this.canBrowseAttendees = false,
  });

  final TeamMembership membership;
  final int eventId;
  final String eventName;
  final bool canRevoke;

  final bool canBrowseAttendees;

  @override
  State<TeamCheckInPage> createState() => _TeamCheckInPageState();
}

class _TeamCheckInPageState extends State<TeamCheckInPage> {
  final _qrController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<EventAttendee> _attendees = [];
  ResolvedAttendee? _scanned;
  String _query = '';
  bool _working = false;
  List<EventQuestionAnswerModel> _scannedQa = [];
  bool _qaLoading = false;
  String? _qaError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.canBrowseAttendees) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final attendees =
          await OrganizerMemberApiService.getEventAttendees(widget.eventId);
      if (!mounted) return;
      setState(() {
        _attendees = attendees;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<EventAttendee> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _attendees;
    return _attendees.where((a) {
      final national = (a.nationalId ?? '').toLowerCase();
      return a.fullName.toLowerCase().contains(q) ||
          a.email.toLowerCase().contains(q) ||
          a.phoneNum.toLowerCase().contains(q) ||
          national.contains(q) ||
          a.attendeeId.toString() == q;
    }).toList();
  }

  Future<void> _checkIn(EventAttendee attendee) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await OrganizerMemberApiService.checkInAttendee(
        eventId: widget.eventId,
        attendeeId: attendee.attendeeId,
      );
      if (!mounted) return;
      _snack('${attendee.fullName} checked in');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _revoke(EventAttendee attendee, bool isValid) async {
    if (_working) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isValid ? 'Re-validate ticket?' : 'Revoke ticket?'),
        content: Text(
          isValid
              ? '${attendee.fullName} will be able to check in again.'
              : '${attendee.fullName} will no longer be allowed to enter. '
                  'This can be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isValid ? 'Re-validate' : 'Revoke',
              style: TextStyle(color: isValid ? _kGreen : _kRed),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _working = true);
    try {
      await OrganizerMemberApiService.revokeTicket(
        eventId: widget.eventId,
        attendeeId: attendee.attendeeId,
        isValid: isValid,
      );
      if (!mounted) return;
      _snack(isValid
          ? 'Ticket re-validated'
          : '${attendee.fullName}\'s ticket was revoked');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _submitQr(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (_working) return;

    final parsed = _parseTicketQr(text);
    if (parsed.eventId != null && parsed.eventId != widget.eventId) {
      _snack('This ticket is for a different event.');
      return;
    }
    final attendeeId = parsed.attendeeId ?? int.tryParse(text);
    if (attendeeId == null) {
      _snack('Could not read the ticket. Scan the QR code or paste its text.');
      return;
    }

    await _resolveScanned(attendeeId);
  }

  Future<void> _resolveScanned(int attendeeId) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final resolved =
          await OrganizerMemberApiService.resolveAttendeeForCheckIn(
        eventId: widget.eventId,
        attendeeId: attendeeId,
      );
      if (!mounted) return;
      setState(() {
        _scanned = resolved;
        _scannedQa = [];
        _qaError = null;
        _working = false;
      });
      _loadScannedQa(resolved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanned = null;
        _scannedQa = [];
        _qaError = null;
        _working = false;
      });
      _snack('$e');
    }
  }

  Future<void> _checkInScanned(ResolvedAttendee attendee) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await OrganizerMemberApiService.checkInAttendee(
        eventId: widget.eventId,
        attendeeId: attendee.attendeeId,
      );
      if (!mounted) return;
      _snack('${attendee.fullName} checked in');
      final refreshed =
          await OrganizerMemberApiService.resolveAttendeeForCheckIn(
        eventId: widget.eventId,
        attendeeId: attendee.attendeeId,
      );
      if (!mounted) return;
      setState(() => _scanned = refreshed);
      _loadScannedQa(refreshed);
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancelScannedCheckIn(ResolvedAttendee attendee) async {
    if (_working) return;
    final ok = await _confirmCancel(attendee.fullName);
    if (ok != true || !mounted) return;
    setState(() => _working = true);
    try {
      await OrganizerMemberApiService.cancelCheckIn(
        eventId: widget.eventId,
        attendeeId: attendee.attendeeId,
      );
      if (!mounted) return;
      _snack('Check-in cancelled for ${attendee.fullName}');
      final refreshed =
          await OrganizerMemberApiService.resolveAttendeeForCheckIn(
        eventId: widget.eventId,
        attendeeId: attendee.attendeeId,
      );
      if (!mounted) return;
      setState(() => _scanned = refreshed);
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancelAttendeeCheckIn(EventAttendee attendee) async {
    if (_working) return;
    final ok = await _confirmCancel(attendee.fullName);
    if (ok != true || !mounted) return;
    setState(() => _working = true);
    try {
      await OrganizerMemberApiService.cancelCheckIn(
        eventId: widget.eventId,
        attendeeId: attendee.attendeeId,
      );
      if (!mounted) return;
      _snack('Check-in cancelled for ${attendee.fullName}');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool?> _confirmCancel(String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel check-in?'),
        content: Text('$name will be marked as not checked in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cancel check-in',
              style: TextStyle(color: _kRed),
            ),
          ),
        ],
      ),
    );
  }

  void _clearScan() {
    setState(() {
      _scanned = null;
      _scannedQa = [];
      _qaError = null;
      _qrController.clear();
    });
  }

  Future<void> _loadScannedQa(ResolvedAttendee attendee) async {
    setState(() {
      _qaLoading = true;
      _qaError = null;
    });
    try {
      final qa = await AttendeeResponseApiService.getQuestionResponsesForCheckIn(
        eventId: widget.eventId,
        attendeeId: attendee.attendeeId,
      );
      if (!mounted) return;
      setState(() {
        _scannedQa = qa;
        _qaLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scannedQa = [];
        _qaLoading = false;
        _qaError = '$e';
      });
    }
  }

  ({int? eventId, int? attendeeId}) _parseTicketQr(String raw) {
    final data = raw.trim().toUpperCase();
    final attendee = RegExp(r'(?:^|:)A(\d+)').firstMatch(data);
    final event = RegExp(r'(?:^|:)EV(\d+)').firstMatch(data);
    return (
      eventId: event == null ? null : int.tryParse(event.group(1)!),
      attendeeId: attendee == null ? null : int.tryParse(attendee.group(1)!),
    );
  }

  Future<void> _scanWithCamera() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const TicketScannerPage()),
    );
    if (code == null || !mounted) return;
    setState(() {
      _scanned = null;
      _scannedQa = [];
      _qaError = null;
      _qrController.text = code;
    });
    await _submitQr(code);
  }

  Future<void> _openDetail(EventAttendee attendee) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AttendeeDetailSheet(
        attendee: attendee,
        onCheckIn: () => _checkIn(attendee),
        onCancel: () => _cancelAttendeeCheckIn(attendee),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Check-in',
              style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800),
            ),
            Text(
              widget.eventName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kTextGrey, fontSize: 12),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(),
      body: Column(
        children: [
          _qrEntry(context),
          if (widget.canBrowseAttendees && _scanned == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, phone or national ID…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(
            child: (widget.canBrowseAttendees && _scanned == null)
                ? _buildList()
                : _buildScanResult(),
          ),
        ],
      ),
    );
  }

  Widget? _bottomBar() {
    final scanned = _scanned;
    if (scanned == null || !scanned.isValid) return null;
    final checkedIn = scanned.checkedIn;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _working
                ? null
                : () => checkedIn
                    ? _cancelScannedCheckIn(scanned)
                    : _checkInScanned(scanned),
            icon: Icon(
              checkedIn ? Icons.undo : Icons.event_available,
              size: 20,
            ),
            label: Text(checkedIn ? 'Cancel check-in' : 'Check in'),
            style: ElevatedButton.styleFrom(
              backgroundColor: checkedIn ? _kRed : kAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanResult() {
    final scanned = _scanned;
    if (scanned == null) {
      if (_working) {
        return const Center(child: CircularProgressIndicator(color: kAccent));
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        children: const [
          Icon(Icons.qr_code_scanner, size: 44, color: _kTextGrey),
          SizedBox(height: 14),
          Text(
            'Scan a ticket to verify it',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kTextDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Check each guest in as they arrive. Attendee contact details are '
            'not shown to volunteers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kTextGrey, fontSize: 12.5),
          ),
        ],
      );
    }

    final statusColor = !scanned.isValid
        ? _kRed
        : (scanned.checkedIn ? _kGreen : const Color(0xFFFF8F00));
    final statusLabel = !scanned.isValid
        ? 'REVOKED'
        : (scanned.checkedIn ? 'CHECKED IN' : 'STILL VALID');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scanned.fullName,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _working ? null : _clearScan,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Clear',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '#${scanned.attendeeId} · ${scanned.ticketTypeName}',
                style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (scanned.checkedIn && scanned.checkedInAt != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Checked in at ${scanned.checkedInAt}',
                  style: const TextStyle(color: _kTextGrey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        ..._qaChildren(),
      ],
    );
  }

  List<Widget> _qaChildren() {
    if (_qaLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator(color: kAccent)),
        ),
      ];
    }
    final error = _qaError;
    if (error != null) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Registration answers unavailable: $error',
            style: const TextStyle(color: _kRed, fontSize: 12.5),
          ),
        ),
      ];
    }
    if (_scannedQa.isEmpty) return const [];

    return [
      const Padding(
        padding: EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          'Registration answers',
          style: TextStyle(
            color: _kTextDark,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      for (var i = 0; i < _scannedQa.length; i++) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Q${i + 1}. ${_scannedQa[i].question}',
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A. ${_scannedQa[i].answer ?? 'not answered'}',
                style: const TextStyle(color: _kTextDark, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _qrEntry(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: kAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Scan or enter the ticket code',
                style: TextStyle(
                  color: _kTextDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _working ? null : _scanWithCamera,
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: const Text('Scan with camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qrController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'TICKET:EV..:O..:A..:T..',
                    hintStyle: const TextStyle(fontSize: 12.5),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onSubmitted: _submitQr,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: _working
                      ? null
                      : () => _submitQr(_qrController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.search, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }
    final error = _error;
    if (error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No attendees found for this event.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextGrey),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: visible.length,
        itemBuilder: (context, index) =>
            _attendeeTile(context, visible[index]),
      ),
    );
  }

  Widget _attendeeTile(BuildContext context, EventAttendee attendee) {
    final statusColor = !attendee.isValid
        ? _kRed
        : (attendee.checkedIn ? _kGreen : const Color(0xFFFF8F00));
    final statusLabel = !attendee.isValid
        ? 'REVOKED'
        : (attendee.checkedIn ? 'CHECKED IN' : 'STILL VALID');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attendee.fullName,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#${attendee.attendeeId} · ${attendee.ticketTypeName} · '
                      '${attendee.email}',
                      style: const TextStyle(color: _kTextGrey, fontSize: 12),
                    ),
                    if (attendee.nationalId != null &&
                        attendee.nationalId!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'National ID: ${attendee.nationalId}',
                        style: const TextStyle(color: _kTextGrey, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(statusColor, statusLabel),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (attendee.isValid && !attendee.checkedIn)
                _tileAction(
                  icon: Icons.event_available,
                  label: 'Check in',
                  color: _kGreen,
                  busy: _working,
                  onTap: () => _checkIn(attendee),
                ),
              if (attendee.isValid && attendee.checkedIn)
                _tileAction(
                  icon: Icons.undo,
                  label: 'Cancel check-in',
                  color: _kRed,
                  busy: _working,
                  onTap: () => _cancelAttendeeCheckIn(attendee),
                ),
              if (widget.canRevoke)
                _tileAction(
                  icon: attendee.isValid
                      ? Icons.block
                      : Icons.event_available,
                  label: attendee.isValid ? 'Revoke' : 'Re-validate',
                  color: _kRed,
                  busy: _working,
                  onTap: () => _revoke(attendee, !attendee.isValid),
                ),
              _tileAction(
                icon: Icons.receipt_long_outlined,
                label: 'Details',
                color: kAccent,
                busy: false,
                onTap: () => _openDetail(attendee),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _tileAction({
    required IconData icon,
    required String label,
    required Color color,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kAccent,
                ),
              ),
              const SizedBox(width: 5),
            ] else
              Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendeeDetailSheet extends StatelessWidget {
  const _AttendeeDetailSheet({
    required this.attendee,
    this.onCheckIn,
    this.onCancel,
  });

  final EventAttendee attendee;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCancel;

  Widget _confirmArea(BuildContext context) {
    if (!attendee.isValid) {
      return const Text(
        'This ticket has been revoked.',
        style: TextStyle(color: _kRed, fontWeight: FontWeight.w700),
      );
    }
    if (attendee.checkedIn) {
      final at = attendee.checkedInAt;
      final cancel = onCancel;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            at == null ? 'Already checked in.' : 'Already checked in at $at.',
            style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w700),
          ),
          if (cancel != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  cancel();
                },
                icon: const Icon(Icons.undo, size: 20),
                label: const Text('Cancel check-in'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kRed,
                  side: const BorderSide(color: _kRed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }
    final callback = onCheckIn;
    if (callback == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compare the guest\'s ID with the details above, then confirm.',
          style: TextStyle(color: _kTextGrey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              callback();
            },
            icon: const Icon(Icons.event_available, size: 20),
            label: const Text('Confirm check-in'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Attendee details',
                      style: TextStyle(
                        color: _kTextDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attendee.fullName,
                    style: const TextStyle(
                      color: _kTextDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _row('Ticket', attendee.ticketTypeName),
                  _row('Price', '${attendee.ticketPrice} Kip'),
                  _row('Email', attendee.email),
                  _row('Phone', attendee.phoneNum),
                  if (attendee.nationalId != null)
                    _row('National ID', attendee.nationalId!),
                  const SizedBox(height: 10),
                  _confirmArea(context),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: _QaSection(
                attendee: attendee,
                scrollController: scrollController,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: _kTextGrey,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _kTextDark, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _QaSection extends StatefulWidget {
  const _QaSection({required this.attendee, required this.scrollController});

  final EventAttendee attendee;
  final ScrollController scrollController;

  @override
  State<_QaSection> createState() => _QaSectionState();
}

class _QaSectionState extends State<_QaSection> {
  bool _loading = true;
  List<EventQuestionModel> _questions = [];
  Map<int, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final qa = await AttendeeResponseApiService.getQuestionResponsesForCheckIn(
        eventId: widget.attendee.eventId,
        attendeeId: widget.attendee.attendeeId,
      );
      if (!mounted) return;
      setState(() {
        _questions = [
          for (final q in qa)
            EventQuestionModel(
              id: q.questionId,
              eventId: widget.attendee.eventId,
              question: q.question,
              questionTypeId: 0,
              isRequire: false,
              sortOrder: q.sortOrder,
            ),
        ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _answers = {
          for (final q in qa)
            if (q.answer != null) q.questionId: q.answer!,
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _questions = [];
        _answers = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }
    if (_questions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No registration questions for this event.',
          style: TextStyle(color: _kTextGrey, fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        final answer = _answers[q.id] ?? '— not answered —';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Q${index + 1}. ${q.question}',
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A. $answer',
                style: const TextStyle(color: _kTextDark, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}