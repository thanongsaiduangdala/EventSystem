import 'package:flutter/material.dart';
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

import 'pill_toggle.dart';
import 'team_manage_page.dart';
import 'team_event_page.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

enum _TeamSection { events, manage }

class TeamMemberDashboardPage extends StatefulWidget {
  const TeamMemberDashboardPage({
    super.key,
    this.membership,
    this.embedded = false,
    this.showOrgPicker = true,
    this.title,
    this.orgIds,
  });

  final Set<int>? orgIds;

  final bool showOrgPicker;

  final String? title;

  final bool embedded;

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
  _TeamSection _section = _TeamSection.events;

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

    final canManage = membership.canManageTeam;
    final section =
        (_section == _TeamSection.manage && !canManage)
            ? _TeamSection.events
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
              if (canManage)
                _sectionToggle(canManage: canManage, current: section),
            ],
          ),
        ),
        Expanded(
          child: switch (section) {
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


  Widget _sectionToggle({
    required bool canManage,
    required _TeamSection current,
  }) {
    final sections = [
      _TeamSection.events,
      if (canManage) _TeamSection.manage,
    ];
    const names = {
      _TeamSection.events: 'Team Events',
      _TeamSection.manage: 'Manage Team',
    };
    return PillToggle(
      labels: [for (final s in sections) names[s]!],
      selected: sections.indexOf(current),
      onChanged: (i) => setState(() => _section = sections[i]),
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
          _orgHeader(membership),
          const SizedBox(height: 16),
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

  Widget _eventCard(BuildContext context, TeamMembership membership, MemberEvent event) {
    final onDuty = membership.isManager || event.canCheckIn;
    final duty = (event.eventRoleName ?? '').trim();
    final roleLine = duty.isEmpty
        ? membership.teamRoleName
        : '${membership.teamRoleName} · $duty';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openEvent(context, membership, event),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
                    const SizedBox(height: 8),
                    Text(
                      roleLine,
                      style: const TextStyle(
                        color: kAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!onDuty)
                Container(
                  margin: const EdgeInsets.only(right: 4),
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
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEvent(
    BuildContext context,
    TeamMembership membership,
    MemberEvent event,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamEventPage(
          membership: membership,
          event: event,
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '${d.year}-$month-$day  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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