import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/search_filter_bar.dart';
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

/// Team management for Admins / Owners: invite members, change roles, assign
/// members to events, remove members, and (Owner only) transfer ownership.
class TeamManagePage extends StatefulWidget {
  const TeamManagePage({
    super.key,
    required this.membership,
    this.embedded = false,
    this.onChanged,
  });

  final TeamMembership membership;

  /// True when shown as a section inside the Team tab (no own app bar).
  final bool embedded;

  /// Called (embedded mode only) after something that changes the caller's
  /// own membership, e.g. an ownership transfer.
  final VoidCallback? onChanged;

  @override
  State<TeamManagePage> createState() => _TeamManagePageState();
}

class _TeamManagePageState extends State<TeamManagePage> {
  bool _loading = true;
  String? _error;
  List<OrgTeamMember> _team = [];
  List<MemberEvent> _events = [];
  List<TeamRoleModel> _roles = [];
  bool _working = false;

  // Member search + filters.
  final _search = TextEditingController();
  int? _roleFilter; // teamRoleId
  int? _statusFilter; // 1 = pending invite, 2 = active

  TeamMembership get _membership => widget.membership;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _search.clear();
    _roleFilter = null;
    _statusFilter = null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        OrganizerMemberApiService.getOrgTeam(_membership.eventOrganizerId),
        OrganizerMemberApiService.getMyMemberEvents(
          orgId: _membership.eventOrganizerId,
        ),
        OrganizerMemberApiService.getAllTeamRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _team = (results[0] as List<OrgTeamMember>);
        _events = (results[1] as MyEventsResult).events;
        _roles = (results[2] as List<TeamRoleModel>)
            .where((r) => r.id != TeamRole.orgOwner)
            .toList();
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _invite() async {
    String? email;
    var roleId = TeamRole.staff;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final emailController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Invite a team member'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'member@example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: roleId,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: [
                      for (final r in _roles)
                        DropdownMenuItem(
                          value: r.id,
                          child: Text(r.name),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => roleId = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    email = emailController.text.trim();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Send invite'),
                ),
              ],
            );
          },
        );
      },
    );

    if (email == null || email!.isEmpty) return;
    try {
      await OrganizerMemberApiService.inviteMember(
        email: email!,
        eventOrganizerId: _membership.eventOrganizerId,
        teamRoleId: roleId,
      );
      if (!mounted) return;
      _snack('Invitation sent to $email');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    }
  }

  Future<void> _changeRole(OrgTeamMember member, int newRoleId) async {
    if (_working || member.teamRoleId == newRoleId) return;
    setState(() => _working = true);
    try {
      await OrganizerMemberApiService.changeMemberRole(
        memberId: member.memberId,
        teamRoleId: newRoleId,
      );
      if (!mounted) return;
      _snack('${member.fullName} is now ${TeamRole.name(newRoleId)}');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _removeMember(OrgTeamMember member) async {
    if (member.isOwner) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          '${member.fullName} will be removed from the team and lose access '
          'to the dashboard, check-in and assigned events.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _working = true);
    try {
      await OrganizerMemberApiService.deleteMember(member.memberId);
      if (!mounted) return;
      _snack('${member.fullName} removed');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editAssignments(OrgTeamMember member) async {
    final assigned =
        member.assignedEvents.map((e) => e.eventId).toSet();
    final selected = {...assigned};
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              builder: (context, scroll) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Assign ${member.fullName} to events',
                              style: const TextStyle(
                                color: _kTextDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, selected),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    if (_events.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('This organization has no events yet.'),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final isOn = selected.contains(event.eventId);
                          return CheckboxListTile(
                            value: isOn,
                            title: Text(
                              event.eventName,
                              style: const TextStyle(
                                color: _kTextDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              _fmtDate(event.start),
                              style: const TextStyle(fontSize: 12),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  selected.add(event.eventId);
                                } else {
                                  selected.remove(event.eventId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() => _working = true);
    try {
      final toAdd = result.difference(assigned);
      final toRemove = assigned.difference(result);
      for (final eventId in toAdd) {
        await OrganizerMemberApiService.assignMemberEvent(
          memberId: member.memberId,
          eventId: eventId,
        );
      }
      for (final eventId in toRemove) {
        await OrganizerMemberApiService.unassignMemberEvent(
          memberId: member.memberId,
          eventId: eventId,
        );
      }
      if (!mounted) return;
      _snack('Assignments updated');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _transferOwner(OrgTeamMember member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer ownership?'),
        content: Text(
          'You will hand the organization to ${member.fullName}, who becomes '
          "the Org Owner. You keep Admin access. This cannot be undone.\n\n"
          'Member: ${member.fullName} (${member.email})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _working = true);
    try {
      await OrganizerMemberApiService.transferOwnership(
        eventOrganizerId: _membership.eventOrganizerId,
        newOwnerMemberId: member.memberId,
      );
      if (!mounted) return;
      _snack('Ownership transferred to ${member.fullName}');
      if (widget.embedded) {
        widget.onChanged?.call();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      // Lives inside the Team tab: the parent provides the Scaffold/app bar.
      return RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        title: const Text(
          'Team',
          style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Invite member',
            onPressed: _loading ? null : _invite,
            icon: const Icon(Icons.person_add_alt, color: kAccent),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
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
      );
    }

    final activeAll = _team
        .where((m) =>
            m.memberStatusId == 2 && m.memberStatusId != 4)
        .toList();
    final pendingAll = _team.where((m) => m.memberStatusId == 1).toList();

    final query = _search.text.trim().toLowerCase();
    bool matches(OrgTeamMember m) {
      if (_roleFilter != null && m.teamRoleId != _roleFilter) return false;
      if (query.isEmpty) return true;
      final haystack = '${m.fullName} ${m.email} ${m.teamRoleName} '
              '${m.assignedEvents.map((e) => e.eventName).join(' ')}'
          .toLowerCase();
      return haystack.contains(query);
    }

    final showActive = _statusFilter == null || _statusFilter == 2;
    final showPending = _statusFilter == null || _statusFilter == 1;
    final active =
        showActive ? activeAll.where(matches).toList() : <OrgTeamMember>[];
    final pending =
        showPending ? pendingAll.where(matches).toList() : <OrgTeamMember>[];
    final filtering =
        query.isNotEmpty || _roleFilter != null || _statusFilter != null;

    final roleNames = <int, String>{
      for (final m in _team) m.teamRoleId: m.teamRoleName,
    };
    final roleIds = roleNames.keys.toList()..sort();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Members',
                style: TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              filtering
                  ? '${active.length} / ${activeAll.length}'
                  : '${active.length}',
              style: const TextStyle(color: _kTextGrey, fontSize: 13),
            ),
            if (widget.embedded) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _invite,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text(
                  'Invite',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(foregroundColor: kAccent),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (_team.isNotEmpty) ...[
          SearchFilterBar(
            controller: _search,
            hint: 'Search members by name, email, role or event...',
            onChanged: (_) => setState(() {}),
            onClearAll: () => setState(_resetFilters),
            groups: [
              if (roleIds.length > 1)
                FilterGroup(
                  label: 'Role',
                  selected: _roleFilter,
                  onChanged: (v) => setState(() => _roleFilter = v as int?),
                  options: [
                    const FilterOption('All', null),
                    for (final id in roleIds) FilterOption(roleNames[id]!, id),
                  ],
                ),
              if (pendingAll.isNotEmpty)
                FilterGroup(
                  label: 'Status',
                  selected: _statusFilter,
                  onChanged: (v) => setState(() => _statusFilter = v as int?),
                  options: const [
                    FilterOption('All', null),
                    FilterOption('Active', 2),
                    FilterOption('Pending invites', 1),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (showActive) ...[
          if (active.isEmpty)
            _EmptyCard(
              text: activeAll.isEmpty
                  ? 'No team members yet. Tap + to invite someone.'
                  : 'No members match your search and filters.',
            )
          else
            for (final member in active) ...[
              _memberCard(member),
              const SizedBox(height: 10),
            ],
        ],
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Pending invitations',
            style: TextStyle(
              color: _kTextDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final member in pending) ...[
            _pendingCard(member),
            const SizedBox(height: 10),
          ],
        ],
        if (!showActive && pending.isEmpty)
          const _EmptyCard(
            text: 'No pending invitations match your search and filters.',
          ),
      ],
    );
  }

  Widget _memberCard(OrgTeamMember member) {
    final isMe = member.accountId == _membership.accountId;
    final isOwnerMember = member.isOwner && _membership.isOwner;
    final canEdit = !member.isOwner && !isMe;

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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  color: kAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${member.fullName}${isMe ? '  (you)' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      member.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kTextGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (member.isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'OWNER',
                    style: TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (canEdit)
            _roleDropdown(member)
          else
            Text(
              member.teamRoleName,
              style: const TextStyle(
                color: kAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canEdit && !_seesAllEvents(member.teamRoleId))
                _chipAction(
                  icon: Icons.event_note,
                  label: 'Assign events',
                  onTap: () => _editAssignments(member),
                ),
              if (canEdit)
                _chipAction(
                  icon: Icons.person_remove_outlined,
                  label: 'Remove',
                  color: const Color(0xFFE53935),
                  onTap: () => _removeMember(member),
                ),
              if (isOwnerMember)
                _chipAction(
                  icon: Icons.workspace_premium,
                  label: 'Transfer ownership',
                  color: kAccent,
                  onTap: () => _transferOwner(member),
                ),
            ],
          ),
          if (_seesAllEvents(member.teamRoleId))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Has access to every event of the organization.',
                style: TextStyle(color: _kTextGrey, fontSize: 12),
              ),
            ),
          if (member.assignedEvents.isNotEmpty &&
              !_seesAllEvents(member.teamRoleId)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in member.assignedEvents)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEEFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.eventName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pendingCard(OrgTeamMember member) {
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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Color(0xFF8A6D00),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${member.email} · waiting for reply',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _kTextGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _roleDropdown(member),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_seesAllEvents(member.teamRoleId))
                _chipAction(
                  icon: Icons.event_note,
                  label: 'Assign events',
                  onTap: () => _editAssignments(member),
                ),
              _chipAction(
                icon: Icons.close,
                label: 'Cancel invite',
                color: const Color(0xFFE53935),
                onTap: () => _removeMember(member),
              ),
            ],
          ),
          if (member.assignedEvents.isNotEmpty &&
              !_seesAllEvents(member.teamRoleId)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in member.assignedEvents)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEEFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.eventName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Admin / Owner are never event-scoped, so assigning them is meaningless.
  bool _seesAllEvents(int roleId) =>
      roleId == TeamRole.orgAdmin || roleId == TeamRole.orgOwner;

  Widget _roleDropdown(OrgTeamMember member) {
    final hasValue = _roles.any((r) => r.id == member.teamRoleId);
    return DropdownButtonFormField<int>(
      key: ValueKey('role-${member.memberId}-${member.teamRoleId}'),
      initialValue: hasValue ? member.teamRoleId : null,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'Role',
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      items: [
        for (final r in _roles)
          DropdownMenuItem(value: r.id, child: Text(r.name)),
      ],
      onChanged: _working
          ? null
          : (v) {
              if (v != null) _changeRole(member, v);
            },
    );
  }

  Widget _chipAction({
    required IconData icon,
    required String label,
    Color color = kAccent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _working ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
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