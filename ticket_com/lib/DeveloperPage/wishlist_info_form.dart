import 'package:flutter/material.dart';
import '../services/account_api_service.dart';
import '../services/event_api_service.dart';
import '../services/wishlist_api_service.dart';

class WishlistInfoForm extends StatefulWidget {
  const WishlistInfoForm({super.key});

  @override
  State<WishlistInfoForm> createState() => WishlistInfoFormState();
}

class WishlistInfoFormState extends State<WishlistInfoForm> {
  List<AccountModel> _accounts = [];
  bool _loadingAccounts = false;
  int? _selectedAccountId;

  List<EventModel> _events = [];
  bool _loadingEvents = false;
  int? _selectedEventId;

  List<WishlistModel> _wishes = [];
  bool _loadingWishes = false;
  bool _isSubmitting = false;

  bool _showingTable = false;

  final _wishSearchController = TextEditingController();
  List<WishlistModel> _filteredWishes = [];
  int? _filterAccountId; // null = "All Accounts"

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadEvents();
    _loadWishes();
  }

  @override
  void dispose() {
    _wishSearchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final accounts = await AccountApiService.getAllAccounts();
      if (!mounted) return;
      setState(() => _accounts = accounts);
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

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final events = await EventApiService.getAllEvents();
      if (!mounted) return;
      setState(() => _events = events);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> reloadEvents() => _loadEvents();

  Future<void> _loadWishes() async {
    setState(() => _loadingWishes = true);
    try {
      final wishes = await WishlistApiService.getAllWishes();
      if (!mounted) return;
      setState(() => _wishes = wishes);
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load wishlist: $e')));
    } finally {
      if (mounted) setState(() => _loadingWishes = false);
    }
  }

  Future<void> reloadWishes() => _loadWishes();

  // ---------------- helpers ----------------

  String _accountNameFor(int accountId) {
    final match = _accounts.where((a) => a.id == accountId);
    return match.isNotEmpty
        ? '${match.first.firstName} ${match.first.lastName}'
        : 'Account #$accountId';
  }

  String _eventNameFor(int eventId) {
    final match = _events.where((e) => e.id == eventId);
    return match.isNotEmpty ? match.first.name : 'Event #$eventId';
  }

  void _applyFilters() {
    final q = _wishSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredWishes = _wishes.where((wish) {
        final matchesAccount =
            _filterAccountId == null || wish.accountId == _filterAccountId;
        final matchesQuery = q.isEmpty ||
            wish.id.toString().contains(q) ||
            _accountNameFor(wish.accountId).toLowerCase().contains(q) ||
            _eventNameFor(wish.eventId).toLowerCase().contains(q);
        return matchesAccount && matchesQuery;
      }).toList();
    });
  }

  void _filterWishes(String query) => _applyFilters();

  Future<void> _onAccountFilterChanged(int? accountId) async {
    setState(() => _filterAccountId = accountId);
    _applyFilters();
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadWishes();
  }

  Future<void> _openAccountPicker({bool forFilter = false}) async {
    final result = await showDialog<AccountModel>(
      context: context,
      builder: (context) => _AccountPickerDialog(
        accounts: _accounts,
        allowClear: forFilter,
      ),
    );
    if (result == null) return;
    if (forFilter) {
      await _onAccountFilterChanged(result.id == -1 ? null : result.id);
    } else {
      setState(() => _selectedAccountId = result.id);
    }
  }

  Future<void> _openEventPicker() async {
    final result = await showDialog<EventModel>(
      context: context,
      builder: (context) => _EventPickerDialog(events: _events),
    );
    if (result != null) {
      setState(() => _selectedEventId = result.id);
    }
  }

  Future<void> _confirmDeleteWish(WishlistModel wish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove wish?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${_accountNameFor(wish.accountId)} will no longer have '
          '"${_eventNameFor(wish.eventId)}" wished.',
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
        await WishlistApiService.deleteWishById(wish.id);
        _loadWishes();
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
    if (_selectedAccountId == null) {
      _snack('Please select an account');
      return;
    }
    if (_selectedEventId == null) {
      _snack('Please select an event');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await WishlistApiService.createWish(
        accountId: _selectedAccountId!,
        eventId: _selectedEventId!,
      );
      _snack(result['msg']?.toString() ?? 'Wish created');
      setState(() {
        _selectedAccountId = null;
        _selectedEventId = null;
      });
      _loadWishes();
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
    if (_showingTable) {
      return _buildTableView();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap:
                      _loadingAccounts ? null : () => _openAccountPicker(),
                  child: InputDecorator(
                    decoration: _decoration('Account'),
                    child: Text(
                      _selectedAccountId == null
                          ? (_loadingAccounts ? 'Loading...' : 'Tap to select account')
                          : _accountNameFor(_selectedAccountId!),
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
                tooltip: 'Refresh account list',
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap: _loadingEvents ? null : _openEventPicker,
                  child: InputDecorator(
                    decoration: _decoration('Event'),
                    child: Text(
                      _selectedEventId == null
                          ? (_loadingEvents ? 'Loading...' : 'Tap to select event')
                          : _eventNameFor(_selectedEventId!),
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
                tooltip: 'Refresh event list',
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                  : const Text('Add Wish'),
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
              child: const Text('View / Manage Wishlist'),
            ),
          ),
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
              Expanded(
                child: InkWell(
                  onTap: () => _openAccountPicker(forFilter: true),
                  child: InputDecorator(
                    decoration: _decoration('Filter by Account'),
                    child: Text(
                      _filterAccountId == null
                          ? 'All Accounts -- tap to filter'
                          : _accountNameFor(_filterAccountId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_filterAccountId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  tooltip: 'Clear account filter',
                  onPressed: () => _onAccountFilterChanged(null),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadWishes,
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
            controller: _wishSearchController,
            onChanged: _filterWishes,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID, account name, or event name',
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
          child: _loadingWishes
              ? const Center(child: CircularProgressIndicator())
              : _filteredWishes.isEmpty
                  ? const Center(
                      child: Text(
                        'No wishlist entries found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: _filteredWishes.length,
                        itemBuilder: (context, index) {
                          final wish = _filteredWishes[index];
                          return ListTile(
                            title: Text(
                              _accountNameFor(wish.accountId),
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Wished: ${_eventNameFor(wish.eventId)}',
                              style: const TextStyle(color: Colors.white54),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteWish(wish),
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

/// Lightweight searchable account picker, private to this file.
class _AccountPickerDialog extends StatefulWidget {
  final List<AccountModel> accounts;
  final bool allowClear;

  const _AccountPickerDialog({required this.accounts, this.allowClear = false});

  @override
  State<_AccountPickerDialog> createState() => _AccountPickerDialogState();
}

class _AccountPickerDialogState extends State<_AccountPickerDialog> {
  final _searchController = TextEditingController();
  late List<AccountModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.accounts;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.accounts.where((a) {
        return q.isEmpty ||
            a.firstName.toLowerCase().contains(q) ||
            a.lastName.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q) ||
            a.id.toString().contains(q);
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
                  hintText: 'Search accounts',
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
                        'No accounts found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      children: [
                        if (widget.allowClear)
                          ListTile(
                            leading: const Icon(Icons.clear, color: Colors.white70),
                            title: const Text(
                              'All Accounts',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              AccountModel(
                                id: -1,
                                firstName: 'All',
                                lastName: 'Accounts',
                                phoneNum: '',
                                email: '',
                                statusId: 0,
                              ),
                            ),
                          ),
                        for (final account in _filtered)
                          ListTile(
                            title: Text(
                              '${account.firstName} ${account.lastName}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${account.id}  •  ${account.email}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () => Navigator.pop(context, account),
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

/// Lightweight searchable event picker, private to this file.
class _EventPickerDialog extends StatefulWidget {
  final List<EventModel> events;

  const _EventPickerDialog({required this.events});

  @override
  State<_EventPickerDialog> createState() => _EventPickerDialogState();
}

class _EventPickerDialogState extends State<_EventPickerDialog> {
  final _searchController = TextEditingController();
  late List<EventModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.events;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.events.where((e) {
        return q.isEmpty ||
            e.name.toLowerCase().contains(q) ||
            e.id.toString().contains(q);
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
                  hintText: 'Search events',
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
                        'No events found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final event in _filtered)
                          ListTile(
                            title: Text(
                              event.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${event.id}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () => Navigator.pop(context, event),
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
