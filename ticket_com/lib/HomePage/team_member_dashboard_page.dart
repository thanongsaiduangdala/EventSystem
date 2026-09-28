import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/event_analytics_page.dart';
import 'package:ticket_com/HomePage/event_form_page.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

import 'pill_toggle.dart';
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
/// Sections of the Team tab, switched with the pill toggle at the top
/// (same look as the Wish / Followed Organizers toggle).
enum _TeamSection { role, events, manage }

class TeamMemberDashboardPage extends StatefulWidget {
  const TeamMemberDashboardPage({
    super.key,
    this.membership,
    this.embedded = false,
    this.showOrgPicker = true,
    this.title,
    this.orgIds,
  });

  /// Only show memberships of these organizations (e.g. "My Team" shows just
  /// the organizations the person owns, not the ones they joined).
  final Set<int>? orgIds;

  /// Hide the organization dropdown (used when one specific organization was
  /// already chosen from the Team Member list).
  final bool showOrgPicker;

  /// App bar title when not embedded (defaults to 'Team Member Dashboard').
  final String? title;

  /// True when shown as a tab inside another page (no own app bar).
  final bool embedded;

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
  TeamMembership? _selected;
  MyEventsResult? _result;
  _TeamSection _section = _TeamSection.role;

  TeamMembership? get _membership =>
      _selected ?? (_memberships.isNotEmpty ? _memberships.first : null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? orgId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await OrganizerMemberApiService.getMyMemberships();
      final filter = widget.orgIds;
      final memberships = filter == null
          ? all
          : all.where((m) => filter.contains(m.eventOrganizerId)).toList();
      if (!mounted) return;
      if (memberships.isEmpty) {
        setState(() {
          _memberships = [];
          _selected = null;
          _result = null;
          _error = 'You are not part of an organization team yet.';
          _loading = false;
        });
        return;
      }
      // Keep the org the person picked; otherwise the one they came in with.
      final wanted = orgId ?? _selected?.eventOrganizerId ??
          widget.membership?.eventOrganizerId;
      final selected = memberships.firstWhere(
        (m) => m.eventOrganizerId == wanted,
        orElse: () => memberships.first,
      );
      final result = await OrganizerMemberApiService.getMyMemberEvents(
        orgId: selected.eventOrganizerId,
      );
      if (!mounted) return;
      setState(() {
        _memberships = memberships;
        _selected = selected;
        _result = result;
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

  Future<void> _refresh() => _load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFF5F6FA),
              elevation: 0,
              foregroundColor: _kTextDark,
              title: Text(
                widget.title ?? 'Team Member Dashboard',
                style: const TextStyle(
                  color: _kTextDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _orgPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _membership?.eventOrganizerId,
          icon: const Icon(Icons.unfold_more, color: kAccent),
          items: [
            for (final m in _memberships)
              DropdownMenuItem(
                value: m.eventOrganizerId,
                child: Text(
                  '${m.organizerName} · ${m.teamRoleName}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null && id != _membership?.eventOrganizerId) {
              _load(orgId: id);
            }
          },
        ),
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

    // Members without team-management rights only get the first two sections.
    final canManage = membership.canManageTeam;
    final section =
        (_section == _TeamSection.manage && !canManage)
            ? _TeamSection.role
            : _section;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              if (_memberships.length > 1 && widget.showOrgPicker) ...[
                _orgPicker(),
                const SizedBox(height: 12),
              ],
              _sectionToggle(canManage: canManage, current: section),
            ],
          ),
        ),
        Expanded(
          child: switch (section) {
            _TeamSection.role => _roleSection(membership),
            _TeamSection.events => _eventsSection(membership),
            _TeamSection.manage => TeamManagePage(
                key: ValueKey('manage-${membership.eventOrganizerId}'),
                membership: membership,
                embedded: true,
                onChanged: _refresh,
              ),
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Section toggle (shared PillToggle, same style as the Wish page)
  // -------------------------------------------------------------------------

  Widget _sectionToggle({
    required bool canManage,
    required _TeamSection current,
  }) {
    final sections = [
      _TeamSection.role,
      _TeamSection.events,
      if (canManage) _TeamSection.manage,
    ];
    const names = {
      _TeamSection.role: 'Your role',
      _TeamSection.events: 'Team Events',
      _TeamSection.manage: 'Manage Team',
    };
    return PillToggle(
      labels: [for (final s in sections) names[s]!],
      selected: sections.indexOf(current),
      onChanged: (i) => setState(() => _section = sections[i]),
    );
  }

  // -------------------------------------------------------------------------
  // Sections
  // -------------------------------------------------------------------------

  Widget _roleSection(TeamMembership membership) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _orgHeader(membership),
          const SizedBox(height: 16),
          _capabilitiesCard(membership),
          if (membership.isManager || membership.isDesigner) ...[
            const SizedBox(height: 16),
            _permissionNote(membership),
          ],
        ],
      ),
    );
  }

  Widget _eventsSection(TeamMembership membership) {
    final events = _result?.events ?? [];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            children: [
              const Text(
                'Team Events',
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
            _EmptyCard(
              text: membership.isManager
                  ? 'No events in your organization yet.'
                  : 'You are not assigned to any events yet. Ask an Admin to assign you.',
            )
          else
            for (final event in events) ...[
              _eventCard(context, membership, event),
              const SizedBox(height: 12),
            ],
        ],
      ),
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
      caps.add((icon: Icons.insights_outlined, text: 'View full event details & analytics'));
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
    // Page content is edited by Page Designers and managers only; Staff can
    // see full event details and attendees but never edit the page.
    final canDesign = membership.isManager || membership.isDesigner;
    // Full event details + analytics: Staff (assigned events) and managers.
    final canSeeDetails =
        membership.isManager || (membership.isStaff && event.assigned);

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
              if (canSeeDetails)
                _actionButton(
                  icon: Icons.insights_outlined,
                  label: 'Details & analytics',
                  onTap: () => _openAnalytics(context, event),
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
    // Browsing the attendee list and revoking tickets are both Staff+
    // capabilities; a Volunteer only gets the scan box.
    final canBrowseAttendees = membership.isStaff || membership.isManager;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamCheckInPage(
          membership: membership,
          eventId: event.eventId,
          eventName: event.eventName,
          canRevoke: canRevoke,
          canBrowseAttendees: canBrowseAttendees,
        ),
      ),
    );
  }

  Future<void> _openAnalytics(BuildContext context, MemberEvent event) async {
    // The analytics screen loads its own data through the role-scoped
    // /analytics endpoint, so no ticket types need to be passed in.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventAnalyticsPage(
          event: event.toEventModel(),
          ticketTypes: const [],
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