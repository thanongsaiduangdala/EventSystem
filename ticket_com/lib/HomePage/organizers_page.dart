import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/event_form_page.dart';
import 'package:ticket_com/services/account_api_service.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/identity_verification_api_service.dart';

const Color _kAccent = Color(0xFF5B4DFF);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kGreen = Color(0xFF2E9E5B);
const Color _kAmber = Color(0xFFB26A00);
const Color _kRed = Color(0xFFE53935);

enum _OrganizerTab { users, events }

/// Full-screen organizer browser opened from Settings. The "Organizers" tab
/// lists accounts that have the "organizer" status (StatusID 2) AND an
/// accepted identity verification (VerificationStatusID 2). The "Events" tab
/// (visible to organizers/admins) lets them create, edit and remove events,
/// with new/edited events pending admin approval.
class OrganizersPage extends StatefulWidget {
  const OrganizersPage({super.key});

  @override
  State<OrganizersPage> createState() => _OrganizersPageState();
}

class _OrganizersPageState extends State<OrganizersPage> {
  bool _loading = true;
  String? _error;

  List<AccountModel> _organizers = [];
  List<EventModel> _events = [];
  Map<int, String> _organizerNames = {};

  _OrganizerTab _tab = _OrganizerTab.users;

  bool get _canManageEvents {
    final session = AuthService.currentSession;
    return session != null && (session.isOrganizer || session.isSuperAdmin);
  }

  bool get _canApprove {
    final session = AuthService.currentSession;
    return session != null &&
        (session.isSuperAdmin || session.hasPermission('update_event'));
  }

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
      final results = await Future.wait<Object>([
        AccountApiService.getAllAccounts(),
        IdentityVerificationApiService.getVerifiedAccountsForOrganizer(),
        if (_canManageEvents)
          EventApiService.getAllEventsWithStatus()
        else
          Future.value(<EventModel>[]),
        if (_canManageEvents)
          EventApiService.getAllOrganizers()
        else
          Future.value(<EventOrganizer>[]),
      ]);
      final accounts = results[0] as List<AccountModel>;
      final verified = results[1] as List<VerifiedAccountModel>;
      final verifiedIds = verified.map((v) => v.accountId).toSet();
      final organizers = accounts
          .where((a) => a.statusId == 2 && verifiedIds.contains(a.id))
          .toList()
        ..sort((a, b) {
          final an = '${a.firstName} ${a.lastName}'.trim();
          final bn = '${b.firstName} ${b.lastName}'.trim();
          return an.toLowerCase().compareTo(bn.toLowerCase());
        });

      List<EventModel> events = [];
      Map<int, String> organizerNames = {};
      if (_canManageEvents) {
        events = results[2] as List<EventModel>;
        final orgs = results[3] as List<EventOrganizer>;
        organizerNames = {for (final o in orgs) o.id: o.name};
      }
      if (!mounted) return;
      setState(() {
        _organizers = organizers;
        _events = events;
        _organizerNames = organizerNames;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      floatingActionButton: _canManageEvents && _tab == _OrganizerTab.events
          ? FloatingActionButton.extended(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              onPressed: _openCreateEvent,
              icon: const Icon(Icons.add),
              label: const Text(
                'Create Event',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: const Text(
          'Organizers',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          if (_canManageEvents) _tabSelector(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _tabSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _tabChip(_OrganizerTab.users),
          const SizedBox(width: 10),
          _tabChip(_OrganizerTab.events),
        ],
      ),
    );
  }

  Widget _tabChip(_OrganizerTab tab) {
    final selected = _tab == tab;
    final label = tab == _OrganizerTab.users
        ? 'Organizers'
        : 'Events (${_events.where((e) => e.eventStatusId == EventStatus.pending).length} pending)';
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _kAccent : const Color(0xFFF0F0F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : _kTextGrey,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kAccent));
    }
    final isEmptyCurrent = _tab == _OrganizerTab.users
        ? _organizers.isEmpty
        : _events.isEmpty;
    if (_error != null && isEmptyCurrent) {
      return _errorBox();
    }
    return RefreshIndicator(
      color: _kAccent,
      backgroundColor: Colors.white,
      onRefresh: _load,
      child: _tab == _OrganizerTab.users ? _usersBody() : _eventsBody(),
    );
  }

  Widget _usersBody() {
    if (_organizers.isEmpty) return _emptyBox('No approved organizers yet');
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _organizers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _organizerCard(_organizers[index]),
    );
  }

  Widget _eventsBody() {
    if (_events.isEmpty) return _emptyBox('No events yet');
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _events.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _eventCard(_events[index]),
    );
  }

  // ---------------- organizer (user) card ----------------

  Widget _organizerCard(AccountModel organizer) {
    final name = '${organizer.firstName} ${organizer.lastName}'.trim();
    final displayName = name.isEmpty ? 'Organizer' : name;
    final initial = displayName.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
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
          _avatar(initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (organizer.email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    organizer.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: _kTextGrey, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 6),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: _kGreen, size: 15),
                    SizedBox(width: 4),
                    Text(
                      'Identity Verified',
                      style: TextStyle(
                        color: _kGreen,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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

  Widget _avatar(String initial) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kAccent, Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ---------------- event card ----------------

  Widget _eventCard(EventModel event) {
    final orgName =
        _organizerNames[event.organizerId] ?? 'Organizer #${event.organizerId}';
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusChip(event.eventStatusId),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFF1E88E5), size: 20),
                tooltip: 'Edit',
                onPressed: () => _openEditEvent(event),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline,
                    color: _kRed, size: 20),
                tooltip: 'Remove',
                onPressed: () => _confirmDeleteEvent(event),
              ),
            ],
          ),
          Text(
            event.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.business_outlined, color: _kTextGrey, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  orgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(event.start)}  →  ${_fmt(event.end)}',
            style: const TextStyle(color: _kTextGrey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                event.eventVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 16,
                color: event.eventVisible ? _kGreen : _kTextGrey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.eventVisible
                      ? 'Visible to the public'
                      : 'Hidden from the public',
                  style: const TextStyle(
                    color: _kTextGrey,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: event.eventVisible,
                activeColor: _kGreen,
                onChanged: (val) => _toggleEventVisibility(event, val),
              ),
            ],
          ),
          if (_canApprove && event.eventStatusId != EventStatus.approved) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (event.eventStatusId != EventStatus.denied)
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _setEventStatus(
                          event, EventStatus.denied, 'Event rejected'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Reject',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                if (event.eventStatusId != EventStatus.denied)
                  const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _setEventStatus(
                        event, EventStatus.approved,
                        'Event approved and now visible to everyone'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Approve',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(int statusId) {
    final (bg, fg, label) = switch (statusId) {
      EventStatus.approved => (_kGreen, Colors.white, 'Approved'),
      EventStatus.denied => (_kRed, Colors.white, 'Denied'),
      _ => (const Color(0xFFFFF3E0), _kAmber, 'Pending Approval'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _fmt(DateTime dt) => '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  // ---------------- event actions ----------------

  void _openCreateEvent() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EventFormPage()),
    ).then((saved) {
      if (saved == true) {
        _snack('Event created. It will be visible after approval.');
        _load();
      }
    });
  }

  void _openEditEvent(EventModel event) {
    // Editing keeps the event's current approval status (Approved stays
    // Approved, Pending stays Pending); only a previously-Denied event goes
    // back to Pending, since editing it is effectively a resubmission.
    final wasDenied = event.eventStatusId == EventStatus.denied;
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => EventFormPage(event: event)),
    ).then((saved) {
      if (saved == true) {
        _snack(wasDenied
            ? 'Event updated and resubmitted for approval.'
            : 'Event updated.');
        _load();
      }
    });
  }

  Future<void> _toggleEventVisibility(EventModel event, bool visible) async {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index == -1) return;
    final previous = _events[index];
    setState(() => _events[index] = previous.copyWith(eventVisible: visible));
    try {
      await EventApiService.setEventVisibility(
        eventId: event.id,
        eventVisible: visible,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _events[index] = previous);
      _snack('Could not update visibility: $e');
    }
  }

  Future<void> _setEventStatus(EventModel event, int status, String msg) async {
    final approved = status == EventStatus.approved;
    try {
      await EventApiService.setEventStatus(
        eventId: event.id,
        eventStatusId: status,
      );
      if (!mounted) return;
      _snack(msg);
      _load();
    } catch (e) {
      _snack('${approved ? 'Approve' : 'Reject'} failed: $e');
    }
  }

  Future<void> _confirmDeleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Remove event?',
            style: TextStyle(color: _kTextDark)),
        content: Text(
          'This will permanently delete "${event.name}".',
          style: const TextStyle(color: _kTextGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await EventApiService.deleteEvent(event.id);
      if (!mounted) return;
      _snack('Event removed');
      _load();
    } catch (e) {
      _snack('Remove failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- shared helpers ----------------

  Widget _errorBox() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: _kTextGrey, size: 40),
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
      ),
    );
  }

  Widget _emptyBox(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Text(
            message,
            style: const TextStyle(color: _kTextGrey),
          ),
        ),
      ],
    );
  }
}