import 'package:flutter/material.dart';
import '../services/account_api_service.dart';

class AccountInfoForm extends StatefulWidget {
  const AccountInfoForm({super.key});

  @override
  State<AccountInfoForm> createState() => AccountInfoFormState();
}

class AccountInfoFormState extends State<AccountInfoForm> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  List<AccountStatus> _statuses = [];
  bool _loadingStatuses = false;
  int? _selectedStatusId;

  List<AccountModel> _accounts = [];
  bool _loadingAccounts = false;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingAccountId;

  final _accountSearchController = TextEditingController();
  List<AccountModel> _filteredAccounts = [];
  int? _filterStatusId; // null = "All Statuses"

  @override
  void initState() {
    super.initState();
    _loadStatuses();
    _loadAccounts();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _accountSearchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadStatuses() async {
    setState(() => _loadingStatuses = true);
    try {
      final statuses = await AccountApiService.getAllAccountStatuses();
      if (!mounted) return;
      setState(() {
        _statuses = statuses;
        if (_selectedStatusId != null &&
            !_statuses.any((s) => s.id == _selectedStatusId)) {
          _selectedStatusId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load account statuses: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingStatuses = false);
    }
  }

  /// Called by the dashboard's refresh button, mirroring reloadOrganizers().
  Future<void> reloadStatuses() => _loadStatuses();

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final accounts = await AccountApiService.getAllAccounts();
      if (!mounted) return;
      setState(() => _accounts = accounts);
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load accounts: $e')));
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> reloadAccounts() => _loadAccounts();

  // ---------------- helpers ----------------

  String _statusNameFor(int statusId) {
    final match = _statuses.where((s) => s.id == statusId);
    return match.isNotEmpty ? match.first.statusType : 'Status #$statusId';
  }

  void _applyFilters() {
    final q = _accountSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredAccounts = _accounts.where((account) {
        final matchesStatus =
            _filterStatusId == null || account.statusId == _filterStatusId;
        final matchesQuery = q.isEmpty ||
            account.id.toString().contains(q) ||
            account.firstName.toLowerCase().contains(q) ||
            account.lastName.toLowerCase().contains(q) ||
            account.email.toLowerCase().contains(q);
        return matchesStatus && matchesQuery;
      }).toList();
    });
  }

  void _filterAccounts(String query) => _applyFilters();

  Future<void> _onStatusFilterChanged(int? statusId) async {
    setState(() => _filterStatusId = statusId);
    _applyFilters();
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadAccounts();
  }

  // Self-contained status picker -- mirrors the organizer picker pattern
  // from EventInfoForm.
  Future<void> _openStatusPicker() async {
    final result = await showDialog<AccountStatus>(
      context: context,
      builder: (context) => _StatusPickerDialog(statuses: _statuses),
    );
    if (result != null) {
      setState(() => _selectedStatusId = result.id);
    }
  }

  Future<void> _openStatusFilterPicker() async {
    final result = await showDialog<AccountStatus>(
      context: context,
      builder: (context) => _StatusPickerDialog(
        statuses: _statuses,
        allowClear: true,
      ),
    );
    if (result != null) {
      await _onStatusFilterChanged(result.id == -1 ? null : result.id);
    }
  }

  void _startEdit(AccountModel account) {
    _firstNameController.text = account.firstName;
    _lastNameController.text = account.lastName;
    _phoneController.text = account.phoneNum;
    _emailController.text = account.email;
    _passwordController.clear();

    setState(() {
      _editingAccountId = account.id;
      _selectedStatusId = account.statusId;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _firstNameController.clear();
    _lastNameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _passwordController.clear();

    setState(() {
      _editingAccountId = null;
      _selectedStatusId = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteAccount(AccountModel account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete account?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${account.firstName} ${account.lastName}".',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await AccountApiService.deleteAccount(account.id);
        _loadAccounts();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStatusId == null) {
      _snack('Please select a status');
      return;
    }

    if (_editingAccountId == null && _passwordController.text.trim().isEmpty) {
      _snack('Please enter a password');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_editingAccountId == null) {
        final result = await AccountApiService.createAccount(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNum: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          statusId: _selectedStatusId!,
          passwordEnc: _passwordController.text.trim(),
        );
        _snack(result['msg']?.toString() ?? 'Account created');
      } else {
        await AccountApiService.updateAccount(
          accountId: _editingAccountId!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNum: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          statusId: _selectedStatusId!,
        );
        _snack('Account updated');
      }

      _startCreate();
      _loadAccounts();
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

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (!value.contains('@') || !value.contains('.')) return 'Invalid email';
    return null;
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    if (_showingTable) {
      return _buildTableView();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_editingAccountId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Account ID: $_editingAccountId',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            TextFormField(
              controller: _firstNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('First Name'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _lastNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Last Name'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Phone Number'),
              keyboardType: TextInputType.phone,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Email'),
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loadingStatuses ? null : _openStatusPicker,
                    child: InputDecorator(
                      decoration: _decoration('Account Status'),
                      child: Text(
                        _selectedStatusId == null
                            ? (_loadingStatuses
                                ? 'Loading...'
                                : 'Tap to select status')
                            : _statusNameFor(_selectedStatusId!),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadingStatuses ? null : _loadStatuses,
                  icon: _loadingStatuses
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh status list',
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_editingAccountId == null) ...[
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('Password'),
                obscureText: true,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
            ],

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
                    : Text(_editingAccountId == null
                        ? 'Create Account'
                        : 'Update Account'),
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
                child: const Text('View / Manage Accounts'),
              ),
            ),

            if (_editingAccountId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Account'),
                ),
              ),
            ],
          ],
        ),
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
              Expanded(
                child: InkWell(
                  onTap: _openStatusFilterPicker,
                  child: InputDecorator(
                    decoration: _decoration('Filter by Status'),
                    child: Text(
                      _filterStatusId == null
                          ? 'All Statuses -- tap to filter'
                          : _statusNameFor(_filterStatusId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_filterStatusId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  tooltip: 'Clear status filter',
                  onPressed: () => _onStatusFilterChanged(null),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadAccounts,
              ),
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
            controller: _accountSearchController,
            onChanged: _filterAccounts,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID, name, or email',
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
          child: _loadingAccounts
              ? const Center(child: CircularProgressIndicator())
              : _filteredAccounts.isEmpty
                  ? const Center(
                      child: Text(
                        'No accounts found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: _filteredAccounts.length,
                        itemBuilder: (context, index) {
                          final account = _filteredAccounts[index];
                          return ListTile(
                            title: Text(
                              '${account.firstName} ${account.lastName}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${account.id}  •  ${account.email}  •  '
                              '${account.phoneNum}  •  '
                              '${_statusNameFor(account.statusId)}',
                              style: const TextStyle(color: Colors.white54),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white70),
                                  onPressed: () => _startEdit(account),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _confirmDeleteAccount(account),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

/// Lightweight searchable status picker. Kept private to this file, mirroring
/// _OrganizerPickerDialog in event_info_form.dart.
class _StatusPickerDialog extends StatefulWidget {
  final List<AccountStatus> statuses;
  final bool allowClear;

  const _StatusPickerDialog({
    required this.statuses,
    this.allowClear = false,
  });

  @override
  State<_StatusPickerDialog> createState() => _StatusPickerDialogState();
}

class _StatusPickerDialogState extends State<_StatusPickerDialog> {
  final _searchController = TextEditingController();
  late List<AccountStatus> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.statuses;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.statuses.where((s) {
        return q.isEmpty ||
            s.statusType.toLowerCase().contains(q) ||
            s.id.toString().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: SizedBox(
        width: 400,
        height: 480,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search statuses',
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search, color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No statuses found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      children: [
                        if (widget.allowClear)
                          ListTile(
                            leading: const Icon(Icons.clear, color: Colors.white70),
                            title: const Text(
                              'All Statuses',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              AccountStatus(id: -1, statusType: 'All Statuses'),
                            ),
                          ),
                        for (final status in _filtered)
                          ListTile(
                            title: Text(
                              status.statusType,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${status.id}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () => Navigator.pop(context, status),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
