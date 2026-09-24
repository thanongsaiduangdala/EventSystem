import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/event_form_page.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_organizer_api_service.dart'
    hide EventOrganizer;
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kGreen = Color(0xFF2E9E5B);
const Color _kAmber = Color(0xFFB26A00);
const Color _kRed = Color(0xFFE53935);

class _TeamMemberView {
  final OrganizerMemberModel member;
  final VerifiedAccount account;
  final TeamRoleModel role;

  _TeamMemberView({required this.member, required this.account, required this.role});
}

/// Organizer dashboard. Shows the organizer profiles owned by the signed-in
/// account, lets the organizer create/manage events and hire other accounts
/// as their employees/volunteers (organizer team members).
class OrganizerDashboardPage extends StatefulWidget {
  const OrganizerDashboardPage({super.key});

  @override
  State<OrganizerDashboardPage> createState() => _OrganizerDashboardPageState();
}

class _OrganizerDashboardPageState extends State<OrganizerDashboardPage> {
  bool _loading = true;
  String? _error;

  int _accountId = 0;

  List<EventOrganizer> _myOrganizers = [];
  List<EventModel> _myEvents = [];
  List<EventOrganizer> _allOrganizers = [];

  List<VerifiedAccount> _verifiedAccounts = [];
  List<TeamRoleModel> _teamRoles = [];
  List<_TeamMemberView> _team = [];

  EventOrganizer? get _primaryOrganizer =>
      _myOrganizers.isEmpty ? null : _myOrganizers.first;

  @override
  void initState() {
    super.initState();
    _accountId = AuthService.currentSession?.accountId ?? 0;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final organizers = await EventApiService.getAllOrganizers();
      final myOrganizers = organizers
          .where((o) => o.createdByAccountId == _accountId)
          .toList();
      final myIds = myOrganizers.map((o) => o.id).toSet();

      List<EventModel> events = [];
      List<OrganizerMemberModel> members = [];
      List<VerifiedAccount> verified = [];
      List<TeamRoleModel> roles = [];
      if (myIds.isNotEmpty) {
        final results = await Future.wait<Object>([
          EventApiService.getAllEventsWithStatus(),
          OrganizerMemberApiService.getAllMembers(),
          EventOrganizerApiService.getVerifiedAccounts(),
          OrganizerMemberApiService.getAllTeamRoles(),
        ]);
        events = (results[0] as List<EventModel>)
            .where((e) => myIds.contains(e.organizerId))
            .toList();
        members = (results[1] as List<OrganizerMemberModel>)
            .where((m) => myIds.contains(m.eventOrganizerId))
            .toList();
        verified = results[2] as List<VerifiedAccount>;
        roles = results[3] as List<TeamRoleModel>;
      }

      final accountsById = {for (final v in verified) v.id: v};
      final rolesById = {for (final r in roles) r.id: r};

      if (!mounted) return;
      setState(() {
        _myOrganizers = myOrganizers;
        _allOrganizers = organizers;
        _myEvents = events;
        _verifiedAccounts = verified;
        _teamRoles = roles;
        _team = members
            .where((m) => accountsById.containsKey(m.accountId))
            .map((m) => _TeamMemberView(
                  member: m,
                  account: accountsById[m.accountId]!,
                  role: rolesById[m.teamRoleId] ??
                      TeamRoleModel(id: m.teamRoleId, name: 'Role #${m.teamRoleId}'),
                ))
            .toList()
          ..sort((a, b) => a.account.fullName.compareTo(b.account.fullName));
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

  // ---------------- events ----------------

  void _openCreateEvent() {
    final organizerId = _primaryOrganizer?.id;
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EventFormPage(organizerId: organizerId),
      ),
    ).then((saved) {
      if (saved == true) {
        _snack('Event created. It will be visible after approval.');
        _load();
      }
    });
  }

  void _openEditEvent(EventModel event) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => EventFormPage(event: event)),
    ).then((saved) {
      if (saved == true) {
        _snack('Event updated. Changes need to be approved again.');
        _load();
      }
    });
  }

  Future<void> _confirmDeleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Remove event?', style: TextStyle(color: _kTextDark)),
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

  // ---------------- team members ----------------

  Future<void> _openAddMember() async {
    final organizer = _primaryOrganizer;
    if (organizer == null) return;
    if (_verifiedAccounts.isEmpty) {
      _snack('No verified accounts available to hire yet.');
      return;
    }
    final allAccounts = _verifiedAccounts.where((v) {
      final already = _team.any((t) => t.member.accountId == v.id);
      return v.id != _accountId && !already;
    }).toList();
    if (allAccounts.isEmpty) {
      _snack('Every verified account is already on your team.');
      return;
    }

    final result = await showModalBottomSheet<_TeamMemberCreate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddMemberSheet(
        accounts: allAccounts,
        roles: _teamRoles,
        organizerName: organizer.name,
      ),
    );
    if (result == null) return;
    try {
      await OrganizerMemberApiService.createMember(
        accountId: result.account.id,
        eventOrganizerId: organizer.id,
        teamRoleId: result.role.id,
      );
      if (!mounted) return;
      _snack('${result.account.fullName} added to your team as ${result.role.name}.');
      _load();
    } catch (e) {
      _snack('Could not add member: $e');
    }
  }

  Future<void> _confirmRemoveMember(_TeamMemberView view) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Remove from team?',
            style: TextStyle(color: _kTextDark)),
        content: Text(
          'Remove ${view.account.fullName} (${view.role.name}) from your '
          'organizer team?',
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
      await OrganizerMemberApiService.deleteMember(view.member.id);
      if (!mounted) return;
      _snack('${view.account.fullName} removed from your team.');
      _load();
    } catch (e) {
      _snack('Remove failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final organizer = _primaryOrganizer;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: const Text(
          'Organizers Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kAccent),
            )
          : _error != null
              ? _errorBox()
              : _myOrganizers.isEmpty
                  ? _noOrganizerBox()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      children: [
                        _organizerHeader(organizer!),
                        const SizedBox(height: 20),
                        _eventsSection(),
                        const SizedBox(height: 24),
                        _teamSection(),
                      ],
                    ),
      floatingActionButton: _myOrganizers.isNotEmpty && _error == null
          ? FloatingActionButton.extended(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              onPressed: _openCreateEvent,
              icon: const Icon(Icons.add),
              label: const Text(
                'Create Event',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
    );
  }

  Widget _organizerHeader(EventOrganizer organizer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kAccent, Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
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
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your organizer account',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      organizer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _headerStat('${_myEvents.length}', 'Events'),
              const SizedBox(width: 24),
              _headerStat('${_team.length}', 'Team members'),
              const Spacer(),
              if (_myOrganizers.length > 1)
                Text(
                  '${_myOrganizers.length} organizer profiles',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _eventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'My Events',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${_myEvents.length}',
              style: const TextStyle(color: _kTextGrey, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_myEvents.isEmpty)
          _emptyCard(
            icon: Icons.event_available_outlined,
            title: 'No events yet',
            message: 'Tap "Create Event" below to publish your first event.',
          )
        else
          ..._myEvents.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _eventCard(e),
              )),
      ],
    );
  }

  Widget _eventCard(EventModel event) {
    final orgName = _organizerNameFor(event.organizerId);
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
                icon: const Icon(Icons.delete_outline, color: _kRed, size: 20),
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

  Widget _teamSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'My Team',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openAddMember,
              style: TextButton.styleFrom(foregroundColor: kAccent),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text(
                'Hire / Add',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Add verified accounts as your employees or volunteers.',
          style: TextStyle(color: _kTextGrey, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        if (_team.isEmpty)
          _emptyCard(
            icon: Icons.groups_outlined,
            title: 'No team members yet',
            message: 'Hire an account to help you run your events.',
          )
        else
          ..._team.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _memberCard(t),
              )),
      ],
    );
  }

  Widget _memberCard(_TeamMemberView view) {
    final account = view.account;
    final initial = account.fullName.isEmpty
        ? '?'
        : account.fullName.characters.first.toUpperCase();
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
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kAccent, Color(0xFF8E2DE2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (account.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    account.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    view.role.name,
                    style: const TextStyle(
                      color: kAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_remove_outlined,
                color: _kRed, size: 21),
            tooltip: 'Remove from team',
            onPressed: () => _confirmRemoveMember(view),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: _kTextGrey, size: 34),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _noOrganizerBox() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      children: [
        const Icon(Icons.storefront_outlined, color: _kTextGrey, size: 48),
        const SizedBox(height: 12),
        const Text(
          'No organizer profile yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kTextDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your organizer account has organizer access, but no organizer '
          'profile is linked to your account yet. Ask an admin to create one '
          'for you.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _kTextGrey, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _load,
          style: FilledButton.styleFrom(backgroundColor: kAccent),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

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
              style: FilledButton.styleFrom(backgroundColor: kAccent),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _organizerNameFor(int organizerId) {
    final match = _allOrganizers.where((o) => o.id == organizerId);
    return match.isEmpty ? 'Organizer #$organizerId' : match.first.name;
  }

  String _fmt(DateTime dt) => '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _TeamMemberCreate {
  final VerifiedAccount account;
  final TeamRoleModel role;

  _TeamMemberCreate({required this.account, required this.role});
}

class _AddMemberSheet extends StatefulWidget {
  final List<VerifiedAccount> accounts;
  final List<TeamRoleModel> roles;
  final String organizerName;

  const _AddMemberSheet({
    required this.accounts,
    required this.roles,
    required this.organizerName,
  });

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  VerifiedAccount? _selectedAccount;
  TeamRoleModel? _selectedRole;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) _selectedAccount = widget.accounts.first;
    if (widget.roles.isNotEmpty) _selectedRole = widget.roles.first;
  }

  void _submit() {
    if (_selectedAccount == null || _selectedRole == null) return;
    Navigator.pop(
      context,
      _TeamMemberCreate(account: _selectedAccount!, role: _selectedRole!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_alt_1, color: kAccent),
              const SizedBox(width: 8),
              const Text(
                'Hire a team member',
                style: TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Add them to "${widget.organizerName}" as an employee or volunteer.',
            style: const TextStyle(color: _kTextGrey, fontSize: 13),
          ),
          const SizedBox(height: 18),
          const Text(
            'Account (verified)',
            style: TextStyle(
              color: _kTextDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<VerifiedAccount>(
            initialValue: _selectedAccount,
            decoration: _decoration('Select account'),
            items: widget.accounts
                .map((a) => DropdownMenuItem<VerifiedAccount>(
                      value: a,
                      child: Text(
                        a.fullName.isEmpty
                            ? 'Account #${a.id}'
                            : '${a.fullName} (${a.email})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedAccount = v),
          ),
          const SizedBox(height: 16),
          const Text(
            'Team role',
            style: TextStyle(
              color: _kTextDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<TeamRoleModel>(
            initialValue: _selectedRole,
            decoration: _decoration('Select role'),
            items: widget.roles
                .map((r) => DropdownMenuItem<TeamRoleModel>(
                      value: r,
                      child: Text(r.name),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedRole = v),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: kAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Add to Team',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kTextGrey, fontSize: 13.5),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x33000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccent, width: 1.6),
      ),
    );
  }
}