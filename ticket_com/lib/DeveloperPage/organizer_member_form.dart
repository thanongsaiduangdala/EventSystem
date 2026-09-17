import 'package:flutter/material.dart';
import '../services/event_organizer_api_service.dart';
import '../services/organizer_member_api_service.dart';
import './SearchDialog/account_search_dialog.dart';
import './SearchDialog/event_organizer_search_dialog.dart';

class OrganizerMemberForm extends StatefulWidget {
  const OrganizerMemberForm({super.key});

  @override
  State<OrganizerMemberForm> createState() => OrganizerMemberFormState();
}

class OrganizerMemberFormState extends State<OrganizerMemberForm> {
  // Account picker
  List<VerifiedAccount> _accounts = [];
  bool _loadingAccounts = false;
  int? _selectedAccountId;

  // Event Organizer picker
  List<EventOrganizer> _organizers = [];
  bool _loadingOrganizers = false;
  int? _selectedOrganizerId;

  // Team Role dropdown
  List<TeamRoleModel> _teamRoles = [];
  bool _loadingRoles = false;
  int? _selectedTeamRoleId;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingMemberId;

  List<OrganizerMemberModel> _members = [];
  bool _loadingMembers = false;
  final _searchController = TextEditingController();
  List<OrganizerMemberModel> _filteredMembers = [];

  @override
  void initState() {
    super.initState();
    // Small, mostly-static list -- worth loading eagerly so the dropdown
    // isn't empty the first time the form renders.
    _loadTeamRoles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final data = await EventOrganizerApiService.getVerifiedAccounts();
      if (!mounted) return;
      setState(() => _accounts = data);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _loadOrganizers() async {
    setState(() => _loadingOrganizers = true);
    try {
      final data = await EventOrganizerApiService.getAllOrganizers();
      if (!mounted) return;
      setState(() => _organizers = data);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingOrganizers = false);
    }
  }

  Future<void> _loadTeamRoles() async {
    setState(() => _loadingRoles = true);
    try {
      final data = await OrganizerMemberApiService.getAllTeamRoles();
      if (!mounted) return;
      setState(() => _teamRoles = data);
    } catch (e) {
      _snack('Error loading team roles: $e');
    } finally {
      if (mounted) setState(() => _loadingRoles = false);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final data = await OrganizerMemberApiService.getAllMembers();
      if (!mounted) return;
      setState(() => _members = data);
      _applyFilter();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadMembers();
    if (_accounts.isEmpty) _loadAccounts();
    if (_organizers.isEmpty) _loadOrganizers();
  }

  // ---------------- lookups ----------------

  String _accountLabelFor(int accountId) {
    final match = _accounts.where((a) => a.id == accountId);
    if (match.isEmpty) return 'Account #$accountId';
    final a = match.first;
    return a.fullName.isEmpty
        ? 'Account #${a.id}'
        : '${a.fullName} (ID: ${a.id})';
  }

  String _organizerLabelFor(int organizerId) {
    final match = _organizers.where((o) => o.id == organizerId);
    return match.isEmpty ? 'Organizer #$organizerId' : match.first.name;
  }

  String _roleLabelFor(int roleId) {
    final match = _teamRoles.where((r) => r.id == roleId);
    return match.isEmpty ? 'Role #$roleId' : match.first.name;
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredMembers = _members.where((m) {
        if (q.isEmpty) return true;
        return m.id.toString().contains(q) ||
            _accountLabelFor(m.accountId).toLowerCase().contains(q) ||
            _organizerLabelFor(m.eventOrganizerId).toLowerCase().contains(q) ||
            _roleLabelFor(m.teamRoleId).toLowerCase().contains(q);
      }).toList();
    });
  }

  // ---------------- pickers ----------------

  Future<void> _openAccountSearch() async {
    if (_accounts.isEmpty) await _loadAccounts();
    if (!mounted) return;
    final result = await showDialog<VerifiedAccount>(
      context: context,
      builder: (context) => AccountSearchDialog(accounts: _accounts),
    );
    if (result != null) setState(() => _selectedAccountId = result.id);
  }

  Future<void> _openOrganizerSearch() async {
    if (_organizers.isEmpty) await _loadOrganizers();
    if (!mounted) return;
    final result = await showDialog<EventOrganizer>(
      context: context,
      builder: (context) => EventOrganizerSearchDialog(organizers: _organizers),
    );
    if (result != null) setState(() => _selectedOrganizerId = result.id);
  }

  // ---------------- form actions ----------------

  void _startEdit(OrganizerMemberModel member) {
    setState(() {
      _editingMemberId = member.id;
      _selectedAccountId = member.accountId;
      _selectedOrganizerId = member.eventOrganizerId;
      _selectedTeamRoleId = member.teamRoleId;
      _showingTable = false;
    });
    if (_accounts.isEmpty) _loadAccounts();
    if (_organizers.isEmpty) _loadOrganizers();
  }

  void _startCreate() {
    setState(() {
      _editingMemberId = null;
      _selectedAccountId = null;
      _selectedOrganizerId = null;
      _selectedTeamRoleId = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDelete(OrganizerMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Remove team member?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will remove "${_accountLabelFor(member.accountId)}" from '
          '"${_organizerLabelFor(member.eventOrganizerId)}".',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await OrganizerMemberApiService.deleteMember(member.id);
        _loadMembers();
        if (_editingMemberId == member.id) _startCreate();
      } catch (e) {
        _snack('Error: $e');
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_selectedAccountId == null) {
      _snack('Please select an account');
      return;
    }
    if (_selectedOrganizerId == null) {
      _snack('Please select an event organizer');
      return;
    }
    if (_selectedTeamRoleId == null) {
      _snack('Please select a team role');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_editingMemberId == null) {
        final result = await OrganizerMemberApiService.createMember(
          accountId: _selectedAccountId!,
          eventOrganizerId: _selectedOrganizerId!,
          teamRoleId: _selectedTeamRoleId!,
        );
        _snack(result['msg']?.toString() ?? 'Member added');
      } else {
        await OrganizerMemberApiService.updateMember(
          memberId: _editingMemberId!,
          accountId: _selectedAccountId!,
          eventOrganizerId: _selectedOrganizerId!,
          teamRoleId: _selectedTeamRoleId!,
        );
        _snack('Member updated');
      }
      _startCreate();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white),
      ),
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    if (_showingTable) return _buildTableView();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_editingMemberId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Editing Member ID: $_editingMemberId',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap: _loadingAccounts ? null : _openAccountSearch,
                  child: InputDecorator(
                    decoration: _decoration('Account (Verified)'),
                    child: Text(
                      _selectedAccountId == null
                          ? (_loadingAccounts
                                ? 'Loading...'
                                : 'Tap to search verified accounts')
                          : _accountLabelFor(_selectedAccountId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadingAccounts ? null : _loadAccounts,
                icon: _loadingAccounts
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap: _loadingOrganizers ? null : _openOrganizerSearch,
                  child: InputDecorator(
                    decoration: _decoration('Event Organizer'),
                    child: Text(
                      _selectedOrganizerId == null
                          ? (_loadingOrganizers
                                ? 'Loading...'
                                : 'Tap to search organizers')
                          : _organizerLabelFor(_selectedOrganizerId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadingOrganizers ? null : _loadOrganizers,
                icon: _loadingOrganizers
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            initialValue: _selectedTeamRoleId,
            decoration: _decoration('Team Role'),
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white),
            hint: Text(
              _loadingRoles ? 'Loading...' : 'Select a role',
              style: const TextStyle(color: Colors.white54),
            ),
            items: _teamRoles
                .map(
                  (r) => DropdownMenuItem<int>(
                    value: r.id,
                    child: Text(r.name),
                  ),
                )
                .toList(),
            onChanged: _loadingRoles
                ? null
                : (value) => setState(() => _selectedTeamRoleId = value),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _editingMemberId == null
                          ? 'Add Team Member'
                          : 'Update Team Member',
                    ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openTable,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('View / Manage Organizer Members'),
            ),
          ),

          if (_editingMemberId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _startCreate,
                child: const Text('Cancel Edit / Add New Member'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadMembers,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showingTable = false),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilter(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID, account, organizer, or role',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadingMembers
              ? const Center(child: CircularProgressIndicator())
              : _filteredMembers.isEmpty
              ? const Center(
                  child: Text(
                    'No organizer members found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredMembers.length,
                  itemBuilder: (context, index) {
                    final m = _filteredMembers[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF2A2A2A),
                        child: Icon(
                          Icons.person_2_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        _accountLabelFor(m.accountId),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'ID: ${m.id}  •  ${_organizerLabelFor(m.eventOrganizerId)}  •  ${_roleLabelFor(m.teamRoleId)}',
                        style: const TextStyle(color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () => _startEdit(m),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDelete(m),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
