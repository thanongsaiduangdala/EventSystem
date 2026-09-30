import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/event_analytics_page.dart';
import 'package:ticket_com/HomePage/event_form_page.dart';
import 'package:ticket_com/HomePage/team_checkin_page.dart';
import 'package:ticket_com/HomePage/team_images.dart';
import 'package:ticket_com/HomePage/team_scan_access_page.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

class TeamEventPage extends StatelessWidget {
  const TeamEventPage({
    super.key,
    required this.membership,
    required this.event,
    this.cover,
  });

  final TeamMembership membership;
  final MemberEvent event;
  final EventImageModel? cover;

  bool get _isManager => membership.isManager;
  bool get _onDuty => _isManager || event.canCheckIn;
  bool get _canDesign => _isManager || membership.isDesigner;
  bool get _canSeeDetails =>
      _isManager || (membership.isStaff && event.assigned);
  bool get _isDoorRole =>
      _onDuty &&
      (membership.isVolunteer || membership.isStaff || _isManager);
  bool get _canWorkDoor => _isDoorRole && (_isManager || event.scanAllowed);
  bool get _scanLocked => _isDoorRole && !_isManager && !event.scanAllowed;
  bool get _canBrowseAttendees => membership.isStaff || _isManager;

  @override
  Widget build(BuildContext context) {
    final actions = _actions(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        foregroundColor: _kTextDark,
        title: Text(
          event.eventName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _kTextDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _eventHeader(),
          const SizedBox(height: 16),
          _roleCard(),
          if (_isManager || membership.isDesigner) ...[
            const SizedBox(height: 12),
            _permissionNote(),
          ],
          const SizedBox(height: 20),
          const Text(
            'What you can do',
            style: TextStyle(
              color: _kTextDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (actions.isEmpty)
            const _InfoCard(
              text: 'You are not assigned to this event, so there is nothing '
                  'to do here yet. Ask an Admin to assign you.',
            )
          else
            for (final a in actions) ...[
              a,
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _eventHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              EventThumb(image: cover, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.eventName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OrgLogo(
                      path: membership.organizerLogoPath,
                      size: 36,
                      onDark: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _fmtDate(event.start),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          if (event.address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              event.address,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
              ),
            ),
          ],
          if (_isManager) ...[
            const SizedBox(height: 10),
            _pill(event.eventVisible ? 'PUBLIC' : 'HIDDEN'),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _roleCard() {
    final duty = (event.eventRoleName ?? '').trim();
    final caps = _capabilities();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your role for this event',
            style: TextStyle(
              color: _kTextDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _roleChip(membership.teamRoleName, kAccent),
              if (duty.isNotEmpty) _roleChip(duty, const Color(0xFF00897B)),
              if (!_onDuty)
                _roleChip('Not assigned', const Color(0xFF8A6D00)),
            ],
          ),
          if (caps.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final c in caps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(c.icon, color: kAccent, size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.text,
                        style:
                            const TextStyle(color: _kTextDark, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _roleChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  List<({IconData icon, String text})> _capabilities() {
    final caps = <({IconData icon, String text})>[];
    if (membership.isVolunteer && _onDuty) {
      caps.add((
        icon: Icons.qr_code_scanner,
        text: 'Scan tickets & verify attendees at check-in',
      ));
    }
    if ((membership.isStaff && _onDuty) || _isManager) {
      caps.add((
        icon: Icons.event_available,
        text: 'Check in attendees & view attendee details',
      ));
      caps.add((
        icon: Icons.insights_outlined,
        text: 'View full event details & analytics',
      ));
      caps.add((
        icon: Icons.block,
        text: 'Decline / revoke tickets at the door',
      ));
    }
    if (_canDesign) {
      caps.add((
        icon: Icons.design_services,
        text: 'Edit event page content (description, media, tickets, Q&A)',
      ));
    }
    return caps;
  }

  Widget _permissionNote() {
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

  List<Widget> _actions(BuildContext context) {
    return [
      if (_scanLocked)
        _ActionTile(
          icon: Icons.lock_outline,
          title: 'Check-in is off',
          subtitle: 'An Org Admin has not turned on scanning for you yet',
          onTap: null,
        ),
      if (_isManager)
        _ActionTile(
          icon: Icons.tune,
          title: 'Scan access',
          subtitle: 'Choose who can scan tickets at this event',
          onTap: () => _openScanAccess(context),
        ),
      if (_canWorkDoor)
        _ActionTile(
          icon: Icons.qr_code_scanner,
          title: 'Check-in',
          subtitle: _canBrowseAttendees
              ? 'Scan tickets or search attendees'
              : 'Scan tickets and verify guests',
          onTap: () => _openCheckIn(context),
        ),
      if (_isManager)
        _ActionTile(
          icon: Icons.people_alt_outlined,
          title: 'Attendees',
          subtitle: 'Browse attendees, revoke or re-validate tickets',
          onTap: () => _openCheckIn(context),
        ),
      if (_canSeeDetails)
        _ActionTile(
          icon: Icons.insights_outlined,
          title: 'Details & analytics',
          subtitle: 'Sales, attendance and event details',
          onTap: () => _openAnalytics(context),
        ),
      if (_canDesign)
        _ActionTile(
          icon: Icons.edit_outlined,
          title: 'Edit design',
          subtitle: 'Description, media, tickets and Q&A',
          onTap: () => _openEditor(context),
        ),
    ];
  }

  Future<void> _openScanAccess(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamScanAccessPage(
          eventId: event.eventId,
          eventName: event.eventName,
        ),
      ),
    );
  }

  Future<void> _openCheckIn(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamCheckInPage(
          membership: membership,
          eventId: event.eventId,
          eventName: event.eventName,
          canRevoke: membership.isStaff || _isManager,
          canBrowseAttendees: _canBrowseAttendees,
        ),
      ),
    );
  }

  Future<void> _openAnalytics(BuildContext context) async {
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

  Future<void> _openEditor(BuildContext context) async {
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _kTextGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

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
