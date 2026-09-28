import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/event_form_page.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

import 'team_manage_page.dart';
import 'team_checkin_page.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

/// Role-based dashboard for anyone who belongs to an organization's team.
///
/// Capabilities depend on the TeamRoleID on the membership row:
///   Volunteer   -> check in attendees at assigned events
///   Staff/Employee -> check in + manage/revoke tickets at assigned events
///   Page Designer-> edit event page content (description, media, tickets, Q&A)
///   Org Admin   -> everything above on every event + manage the team
///   Org Owner   -> everything Admin does + transfer ownership
class TeamMemberDashboardPage extends StatefulWidget {
  const TeamMemberDashboardPage({super.key, this.membership});

  /// The membership loaded by the Settings screen. When null the page loads
  /// it itself (keeps this page usable directly / after refresh).
  final TeamMembership? membership;

  @override
  State<TeamMemberDashboardPage> createState() => _TeamMemberDashboardPageState();
}

class _TeamMemberDashboardPageState extends State<TeamMemberDashboardPage> {
  bool _loading = true;
  String? _error;
  List<TeamMembership> _memberships = [];
  MyEventsResult? _result;

  TeamMembership? get _membership => widget.membership ??
      (_memberships.isNotEmpty ? _memberships.first : null);

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
        OrganizerMemberApiService.getMyMemberships(),
        OrganizerMemberApiService.getMyMemberEvents(),
      ]);
      if (!mounted) return;
      setState(() {
        _memberships = (results[0] as List<TeamMembership>);
        _result = results[1] as MyEventsResult;
        _loading = false;
      });
      if (_memberships.isEmpty) {
        setState(() => _error = 'You are not part of an organization team yet.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() => _load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        title: const Text(
          'Team Member Dashboard',
          style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }
    final error = _error;
    if (error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.group_work_outlined, size: 56, color: Colors.black26),
          const SizedBox(height: 12),
          const Text(
            'Team Member Dashboard',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey),
          ),
        ],
      );
    }

    final membership = _membership;
    if (membership == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text('No membership', textAlign: TextAlign.center),
        ],
      );
    }

    final events = _result?.events ?? [];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _orgHeader(membership),
        const SizedBox(height: 16),
        _capabilitiesCard(membership),
        const SizedBox(height: 16),
        if (membership.isManager) ...[
          _manageTeamCard(membership),
          const SizedBox(height: 16),
        ],
        if (membership.isManager || membership.isDesigner)
          _permissionNote(membership),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'My Events',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${events.length}',
              style: const TextStyle(color: _kTextGrey, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const _EmptyCard(text: 'No events in your organization yet.')
        else
          for (final event in events) ...[
            _eventCard(context, membership, event),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Header / cards
  // -------------------------------------------------------------------------

  Widget _orgHeader(TeamMembership membership) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B4DFF), Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.apartment, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.organizerName.isEmpty
                          ? 'Your organization'
                          : membership.organizerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      membership.teamRoleName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (membership.isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'OWNER',
                    style: TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (membership.organizerDescription != null &&
              (membership.organizerDescription ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              membership.organizerDescription!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _capabilitiesCard(TeamMembership membership) {
    final cap = _capabilities(membership);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your role',
            style: TextStyle(
              color: _kTextDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final c in cap)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(c.icon, color: kAccent, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.text,
                      style: const TextStyle(color: _kTextDark, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<({IconData icon, String text})> _capabilities(TeamMembership m) {
    final caps = <({IconData icon, String text})>[];
    if (m.isVolunteer) {
      caps.add((icon: Icons.qr_code_scanner, text: 'Scan tickets & verify attendees at check-in'));
    }
    if (m.isStaff || m.isManager) {
      caps.add((icon: Icons.event_available, text: 'Check in attendees & view attendee details'));
    }
    if (m.isStaff || m.isManager) {
      caps.add((icon: Icons.block, text: 'Decline / revoke tickets at the door'));
    }
    if (m.isDesigner) {
      caps.add((icon: Icons.design_services, text: 'Edit event page content (description, media, tickets, Q&A)'));
    }
    if (m.isManager) {
      caps.add((icon: Icons.event_note, text: 'See every event of the organization'));
    }
    if (m.canManageTeam) {
      caps.add((icon: Icons.groups, text: 'Manage the team: invite, assign roles & events'));
    }
    if (m.isOwner) {
      caps.add((icon: Icons.workspace_premium, text: 'Transfer organization ownership'));
    }
    return caps;
  }

  Widget _manageTeamCard(TeamMembership membership) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.groups, color: kAccent, size: 22),
        ),
        title: const Text(
          'Manage Team',
          style: TextStyle(
            color: _kTextDark,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'Invite members, change roles & assign events',
          style: TextStyle(color: _kTextGrey, fontSize: 12.5),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TeamManagePage(membership: membership),
            ),
          );
          if (changed == true) _refresh();
        },
      ),
    );
  }

  Widget _permissionNote(TeamMembership membership) {
    final note = membership.isDesigner
        ? 'Page Designer access is scoped to this organization’s events only. '
            'You cannot see attendee data or check people in.'
        : 'Admin / Owner access covers every event of this organization.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEEFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: kAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Event card + actions
  // -------------------------------------------------------------------------

  Widget _eventCard(BuildContext context, TeamMembership membership, MemberEvent event) {
    final isManager = membership.isManager;
    final canCheckIn = isManager || event.canCheckIn;
    final canDesign = membership.isManager ||
        membership.isDesigner ||
        membership.isStaff;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                      event.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmtDate(event.start)}\n${event.address}',
                      style: const TextStyle(color: _kTextGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!canCheckIn && !isManager)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NOT ASSIGNED',
                    style: TextStyle(
                      color: Color(0xFF8A6D00),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((canCheckIn || isManager) &&
                  (membership.isVolunteer || membership.isStaff || membership.isManager))
                _actionButton(
                  icon: Icons.qr_code_scanner,
                  label: isManager ? 'Check-in' : 'Check-in',
                  onTap: () => _openCheckIn(context, membership, event,
                      canRevoke: membership.isStaff || membership.isManager),
                ),
              if (isManager)
                _actionButton(
                  icon: Icons.people_alt_outlined,
                  label: 'Attendees',
                  onTap: () => _openCheckIn(context, membership, event,
                      canRevoke: true),
                ),
              if (canDesign)
                _actionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit design',
                  onTap: () => _openEditor(context, event),
                ),
              if (isManager)
                _actionButton(
                  icon: Icons.visibility_outlined,
                  label: event.eventVisible ? 'Public' : 'Hidden',
                  onTap: null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: kAccent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCheckIn(
    BuildContext context,
    TeamMembership membership,
    MemberEvent event, {
    required bool canRevoke,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamCheckInPage(
          membership: membership,
          eventId: event.eventId,
          eventName: event.eventName,
          canRevoke: canRevoke,
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, MemberEvent event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventFormPage(event: event.toEventModel()),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '${d.year}-$month-$day  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

extension on MemberEvent {
  EventModel toEventModel() {
    return EventModel(
      id: eventId,
      name: eventName,
      start: start,
      end: end,
      address: address,
      latitude: latitude,
      longitude: longitude,
      description: description,
      organizerId: organizerId,
      onePerPerson: onePerPerson,
      eventStatusId: eventStatusId,
      eventVisible: eventVisible,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _kTextGrey, fontSize: 13),
      ),
    );
  }
}