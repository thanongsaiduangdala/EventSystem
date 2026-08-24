import 'package:flutter/material.dart';
import '../services/account_api_service.dart';
import '../services/category_api_service.dart';
import '../services/account_category_api_service.dart';

class AccountCategoryInfoForm extends StatefulWidget {
  const AccountCategoryInfoForm({super.key});

  @override
  State<AccountCategoryInfoForm> createState() => AccountCategoryInfoFormState();
}

class AccountCategoryInfoFormState extends State<AccountCategoryInfoForm> {
  List<AccountModel> _accounts = [];
  bool _loadingAccounts = false;
  int? _selectedAccountId;

  List<CategoryModel> _categories = [];
  bool _loadingCategories = false;
  int? _selectedCategoryId;

  List<AccountCategoryModel> _favorites = [];
  bool _loadingFavorites = false;
  bool _isSubmitting = false;

  bool _showingTable = false;

  final _favoriteSearchController = TextEditingController();
  List<AccountCategoryModel> _filteredFavorites = [];
  int? _filterAccountId; // null = "All Accounts"

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadCategories();
    _loadFavorites();
  }

  @override
  void dispose() {
    _favoriteSearchController.dispose();
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

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final categories = await CategoryApiService.getAllCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load categories: $e')));
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> reloadCategories() => _loadCategories();

  Future<void> _loadFavorites() async {
    setState(() => _loadingFavorites = true);
    try {
      final favorites = await AccountCategoryApiService.getAllAccountCategories();
      if (!mounted) return;
      setState(() => _favorites = favorites);
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load favorite categories: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingFavorites = false);
    }
  }

  Future<void> reloadFavorites() => _loadFavorites();

  // ---------------- helpers ----------------

  String _accountNameFor(int accountId) {
    final match = _accounts.where((a) => a.id == accountId);
    return match.isNotEmpty
        ? '${match.first.firstName} ${match.first.lastName}'
        : 'Account #$accountId';
  }

  String _categoryNameFor(int categoryId) {
    final match = _categories.where((c) => c.id == categoryId);
    return match.isNotEmpty ? match.first.name : 'Category #$categoryId';
  }

  void _applyFilters() {
    final q = _favoriteSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredFavorites = _favorites.where((fav) {
        final matchesAccount =
            _filterAccountId == null || fav.accountId == _filterAccountId;
        final matchesQuery = q.isEmpty ||
            fav.id.toString().contains(q) ||
            _accountNameFor(fav.accountId).toLowerCase().contains(q) ||
            fav.categoryName.toLowerCase().contains(q);
        return matchesAccount && matchesQuery;
      }).toList();
    });
  }

  void _filterFavorites(String query) => _applyFilters();

  Future<void> _onAccountFilterChanged(int? accountId) async {
    setState(() => _filterAccountId = accountId);
    _applyFilters();
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadFavorites();
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

  Future<void> _openCategoryPicker() async {
    final result = await showDialog<CategoryModel>(
      context: context,
      builder: (context) => _CategoryPickerDialog(categories: _categories),
    );
    if (result != null) {
      setState(() => _selectedCategoryId = result.id);
    }
  }

  Future<void> _confirmDeleteFavorite(AccountCategoryModel fav) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove favorite?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${_accountNameFor(fav.accountId)} will no longer have '
          '"${fav.categoryName}" favorited.',
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
        await AccountCategoryApiService.deleteAccountCategory(fav.id);
        _loadFavorites();
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
    if (_selectedCategoryId == null) {
      _snack('Please select a category');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await AccountCategoryApiService.addAccountCategory(
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
      );
      _snack(result['msg']?.toString() ?? 'Category favorited');
      setState(() {
        _selectedAccountId = null;
        _selectedCategoryId = null;
      });
      _loadFavorites();
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
                  onTap: _loadingCategories ? null : _openCategoryPicker,
                  child: InputDecorator(
                    decoration: _decoration('Category'),
                    child: Text(
                      _selectedCategoryId == null
                          ? (_loadingCategories ? 'Loading...' : 'Tap to select category')
                          : _categoryNameFor(_selectedCategoryId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadingCategories ? null : _loadCategories,
                icon: _loadingCategories
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Refresh category list',
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
                  : const Text('Add Favorite'),
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
              child: const Text('View / Manage Favorites'),
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
                onPressed: _loadFavorites,
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
            controller: _favoriteSearchController,
            onChanged: _filterFavorites,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID, account name, or category name',
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
          child: _loadingFavorites
              ? const Center(child: CircularProgressIndicator())
              : _filteredFavorites.isEmpty
                  ? const Center(
                      child: Text(
                        'No favorite categories found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: _filteredFavorites.length,
                        itemBuilder: (context, index) {
                          final fav = _filteredFavorites[index];
                          return ListTile(
                            title: Text(
                              _accountNameFor(fav.accountId),
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Favorited: ${fav.categoryName}',
                              style: const TextStyle(color: Colors.white54),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteFavorite(fav),
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

/// Lightweight searchable category picker, private to this file.
class _CategoryPickerDialog extends StatefulWidget {
  final List<CategoryModel> categories;

  const _CategoryPickerDialog({required this.categories});

  @override
  State<_CategoryPickerDialog> createState() => _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends State<_CategoryPickerDialog> {
  final _searchController = TextEditingController();
  late List<CategoryModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.categories;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.categories.where((c) {
        return q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.id.toString().contains(q);
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
                  hintText: 'Search categories',
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
                        'No categories found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final category in _filtered)
                          ListTile(
                            title: Text(
                              category.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${category.id}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () => Navigator.pop(context, category),
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
