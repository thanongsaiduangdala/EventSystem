import 'package:flutter/material.dart';
import '../services/event_api_service.dart';
import '../services/event_organizer_api_service.dart' as org_api;
import '../services/organizer_member_api_service.dart';
import '../services/event_staff_api_service.dart';
import './SearchDialog/event_search_dialog.dart';
import './SearchDialog/staff_member_search_dialog.dart';

class EventStaffForm extends StatefulWidget {
  const EventStaffForm({super.key});

  @override
  State<EventStaffForm> createState() => EventStaffFormState();
}

class EventStaffFormState extends State<EventStaffForm> {
  // Event picker
  List<EventModel> _events = [];
  bool _loadingEvents = false;
  int? _selectedEventId;

  // Organizer member picker (and the lookups needed to label it)
  List<OrganizerMemberModel> _members = [];
  bool _loadingMembers = false;
  int? _selectedMemberId;

  List<org_api.VerifiedAccount> _accounts = [];
  List<org_api.EventOrganizer> _organizers = [];
  List<TeamRoleModel> _teamRoles = [];

  // Event role dropdown
  List<EventRoleModel> _eventRoles = [];
  bool _loadingEventRoles = false;
  int? _selectedEventRoleId;

  // Optional assigned-at timestamp
  DateTime? _assignedAt;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingAssignmentId;

  List<EventStaffModel> _staffList = [];
  bool _loadingStaff = false;
  final _searchController = TextEditingController();
  List<EventStaffModel> _filteredStaff = [];

  @override
  void initState() {
    super.initState();
    // Small, fairly static list -- load eagerly for the dropdown.
    _loadEventRoles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final data = await EventApiService.getAllEvents();
      if (!mounted) return;
      setState(() => _events = data);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final results = await Future.wait([
        OrganizerMemberApiService.getAllMembers(),
        org_api.EventOrganizerApiService.getVerifiedAccounts(),
        org_api.EventOrganizerApiService.getAllOrganizers(),
        OrganizerMemberApiService.getAllTeamRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<OrganizerMemberModel>;
        _accounts = results[1] as List<org_api.VerifiedAccount>;
        _organizers = results[2] as List<org_api.EventOrganizer>;
        _teamRoles = results[3] as List<TeamRoleModel>;
      });
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadEventRoles() async {
    setState(() => _loadingEventRoles = true);
    try {
      final data = await EventStaffApiService.getAllEventRoles();
      if (!mounted) return;
      setState(() => _eventRoles = data);
    } catch (e) {
      _snack('Error loading event roles: $e');
    } finally {
      if (mounted) setState(() => _loadingEventRoles = false);
    }
  }

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    try {
      final data = await EventStaffApiService.getAllStaff();
      if (!mounted) return;
      setState(() => _staffList = data);
      _applyFilter();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingStaff = false);
    }
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadStaff();
    if (_events.isEmpty) _loadEvents();
    if (_members.isEmpty) _loadMembers();
  }

  // ---------------- lookups / labels ----------------

  String _eventLabelFor(int eventId) {
    final match = _events.where((e) => e.id == eventId);
    return match.isEmpty ? 'Event #$eventId' : match.first.name;
  }

  String _accountNameFor(int accountId) {
    final match = _accounts.where((a) => a.id == accountId);
    return match.isEmpty ? 'Account #$accountId' : match.first.fullName;
  }

  String _organizerNameFor(int organizerId) {
    final match = _organizers.where((o) => o.id == organizerId);
    return match.isEmpty ? 'Organizer #$organizerId' : match.first.name;
  }

  String _teamRoleNameFor(int teamRoleId) {
    final match = _teamRoles.where((r) => r.id == teamRoleId);
    return match.isEmpty ? '' : match.first.name;
  }

  String _eventRoleLabelFor(int eventRoleId) {
    final match = _eventRoles.where((r) => r.id == eventRoleId);
    return match.isEmpty ? 'Role #$eventRoleId' : match.first.name;
  }

  String _memberDisplayLabel(OrganizerMemberModel m) {
    final accountName = _accountNameFor(m.accountId);
    final orgName = _organizerNameFor(m.eventOrganizerId);
    return '$accountName — $orgName';
  }

  String _memberDisplaySubtitle(OrganizerMemberModel m) {
    final roleName = _teamRoleNameFor(m.teamRoleId);
    return roleName.isEmpty ? 'Team role unknown' : roleName;
  }

  String _memberLabelFor(int memberId) {
    final match = _members.where((m) => m.id == memberId);
    if (match.isEmpty) return 'Member #$memberId';
    return _memberDisplayLabel(match.first);
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredStaff = _staffList.where((s) {
        if (q.isEmpty) return true;
        return s.id.toString().contains(q) ||
            _eventLabelFor(s.eventId).toLowerCase().contains(q) ||
            _memberLabelFor(s.memberId).toLowerCase().contains(q) ||
            _eventRoleLabelFor(s.eventRoleId).toLowerCase().contains(q);
      }).toList();
    });
  }

  // ---------------- pickers ----------------

  Future<void> _openEventSearch() async {
    if (_events.isEmpty) await _loadEvents();
    if (!mounted) return;
    final result = await showDialog<EventModel>(
      context: context,
      builder: (context) => EventSearchDialog(events: _events),
    );
    if (result == null) return;
    setState(() {
      final previousOrgId = _selectedEventId == null
          ? null
          : _eventOrganizerIdFor(_selectedEventId!);
      _selectedEventId = result.id;
      // If a member was already picked for a different organization than
      // the newly-selected event, it's no longer valid -- clear it rather
      // than silently submit a mismatched pair.
      if (_selectedMemberId != null && previousOrgId != result.organizerId) {
        _selectedMemberId = null;
      }
    });
  }

  int? _eventOrganizerIdFor(int eventId) {
    final match = _events.where((e) => e.id == eventId);
    return match.isEmpty ? null : match.first.organizerId;
  }

  Future<void> _openMemberSearch() async {
    if (_selectedEventId == null) {
      _snack('Please select an event first');
      return;
    }
    if (_members.isEmpty) await _loadMembers();
    if (!mounted) return;

    // Only offer members that belong to the same organization as the
    // selected event -- an org's staff roster shouldn't include people
    // from a different organization.
    final eventOrgId = _eventOrganizerIdFor(_selectedEventId!);
    final eligibleMembers = _members
        .where((m) => m.eventOrganizerId == eventOrgId)
        .toList();

    if (eligibleMembers.isEmpty) {
      _snack('This organization has no members yet');
      return;
    }

    final result = await showDialog<OrganizerMemberModel>(
      context: context,
      builder: (context) => StaffMemberSearchDialog(
        members: eligibleMembers,
        labelBuilder: _memberDisplayLabel,
        subtitleBuilder: _memberDisplaySubtitle,
      ),
    );
    if (result != null) setState(() => _selectedMemberId = result.id);
  }

  Future<void> _pickAssignedAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _assignedAt ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_assignedAt ?? now),
    );
    if (time == null) return;
    setState(() {
      _assignedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatAssignedAt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  // ---------------- form actions ----------------

  void _startEdit(EventStaffModel staff) {
    setState(() {
      _editingAssignmentId = staff.id;
      _selectedEventId = staff.eventId;
      _selectedMemberId = staff.memberId;
      _selectedEventRoleId = staff.eventRoleId;
      _assignedAt = staff.assignedAt;
      _showingTable = false;
    });
    if (_events.isEmpty) _loadEvents();
    if (_members.isEmpty) _loadMembers();
  }

  void _startCreate() {
    setState(() {
      _editingAssignmentId = null;
      _selectedEventId = null;
      _selectedMemberId = null;
      _selectedEventRoleId = null;
      _assignedAt = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDelete(EventStaffModel staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Remove staff assignment?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will remove "${_memberLabelFor(staff.memberId)}" from '
          '"${_eventLabelFor(staff.eventId)}".',
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
        await EventStaffApiService.deleteStaff(staff.id);
        _loadStaff();
        if (_editingAssignmentId == staff.id) _startCreate();
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
    if (_selectedEventId == null) {
      _snack('Please select an event');
      return;
    }
    if (_selectedMemberId == null) {
      _snack('Please select an organizer member');
      return;
    }
    if (_selectedEventRoleId == null) {
      _snack('Please select an event role');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_editingAssignmentId == null) {
        final result = await EventStaffApiService.createStaff(
          eventId: _selectedEventId!,
          memberId: _selectedMemberId!,
          eventRoleId: _selectedEventRoleId!,
          assignedAt: _assignedAt,
        );
        _snack(result['msg']?.toString() ?? 'Staff assigned');
      } else {
        await EventStaffApiService.updateStaff(
          assignmentId: _editingAssignmentId!,
          eventId: _selectedEventId!,
          memberId: _selectedMemberId!,
          eventRoleId: _selectedEventRoleId!,
          assignedAt: _assignedAt,
        );
        _snack('Staff assignment updated');
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
          if (_editingAssignmentId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Editing Assignment ID: $_editingAssignmentId',
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
                  onTap: _loadingEvents ? null : _openEventSearch,
                  child: InputDecorator(
                    decoration: _decoration('Event'),
                    child: Text(
                      _selectedEventId == null
                          ? (_loadingEvents ? 'Loading...' : 'Tap to search event')
                          : _eventLabelFor(_selectedEventId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadingEvents ? null : _loadEvents,
                icon: _loadingEvents
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
                  onTap: _loadingMembers ? null : _openMemberSearch,
                  child: InputDecorator(
                    decoration: _decoration('Organizer Member'),
                    child: Text(
                      _selectedMemberId == null
                          ? (_loadingMembers
                                ? 'Loading...'
                                : _selectedEventId == null
                                ? 'Select an event first'
                                : 'Tap to search this organization\'s members')
                          : _memberLabelFor(_selectedMemberId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadingMembers ? null : _loadMembers,
                icon: _loadingMembers
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
            initialValue: _selectedEventRoleId,
            decoration: _decoration('Event Role'),
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white),
            hint: Text(
              _loadingEventRoles ? 'Loading...' : 'Select a role',
              style: const TextStyle(color: Colors.white54),
            ),
            items: _eventRoles
                .map(
                  (r) => DropdownMenuItem<int>(
                    value: r.id,
                    child: Text(r.name),
                  ),
                )
                .toList(),
            onChanged: _loadingEventRoles
                ? null
                : (value) => setState(() => _selectedEventRoleId = value),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickAssignedAt,
                  child: InputDecorator(
                    decoration: _decoration('Assigned At (optional)'),
                    child: Text(
                      _assignedAt == null
                          ? 'Not set -- tap to pick a date/time'
                          : _formatAssignedAt(_assignedAt!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_assignedAt != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  tooltip: 'Clear',
                  onPressed: () => setState(() => _assignedAt = null),
                ),
            ],
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
                      _editingAssignmentId == null
                          ? 'Assign Staff'
                          : 'Update Assignment',
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
              child: const Text('View / Manage Event Staff'),
            ),
          ),

          if (_editingAssignmentId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _startCreate,
                child: const Text('Cancel Edit / Add New Assignment'),
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
                onPressed: _loadStaff,
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
              hintText: 'Search by ID, event, member, or role',
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
          child: _loadingStaff
              ? const Center(child: CircularProgressIndicator())
              : _filteredStaff.isEmpty
              ? const Center(
                  child: Text(
                    'No event staff found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredStaff.length,
                  itemBuilder: (context, index) {
                    final s = _filteredStaff[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF2A2A2A),
                        child: Icon(
                          Icons.assignment_ind_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        _memberLabelFor(s.memberId),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'ID: ${s.id}  •  ${_eventLabelFor(s.eventId)}  •  ${_eventRoleLabelFor(s.eventRoleId)}'
                        '${s.assignedAt != null ? '  •  ${_formatAssignedAt(s.assignedAt!)}' : ''}',
                        style: const TextStyle(color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () => _startEdit(s),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDelete(s),
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
