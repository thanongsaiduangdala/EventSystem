import 'package:flutter/material.dart';
import '../services/event_api_service.dart';
import '../services/category_api_service.dart';
import '../models/category_models.dart';
import '../utils/category_icons.dart';
import './SearchDialog/event_search_dialog.dart';
import './SearchDialog/category_search_dialog.dart';
import './SearchDialog/icon_picker_dialog.dart';

class EventCategoryForm extends StatefulWidget {
  const EventCategoryForm({super.key});

  @override
  State<EventCategoryForm> createState() => EventCategoryFormState();
}

class EventCategoryFormState extends State<EventCategoryForm> {
  final _formKey = GlobalKey<FormState>();

  final _categoryNameController = TextEditingController();
  // Stores a key into categoryIconOptions (e.g. "music"), not a file path/URL.
  String? _selectedIconKey;

  List<EventModel> _events = [];
  int? _selectedEventId;
  bool _loadingEvents = false;

  List<CategoryModel> _categories = [];
  bool _loadingCategories = false;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingEventCategoryId; // the Event<->Category link being edited
  int? _editingCategoryId; // the underlying category being edited/reused

  List<EventCategoryModel> _links = [];
  bool _loadingLinks = false;
  final _linkSearchController = TextEditingController();
  List<EventCategoryModel> _filteredLinks = [];
  int? _filterEventId; // null = "All Events"

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    _linkSearchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final events = await EventApiService.getAllEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        if (_selectedEventId != null &&
            !_events.any((e) => e.id == _selectedEventId)) {
          _selectedEventId = null;
        }
      });
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

  // Backend only supports fetching every link, so pull the full list and
  // filter locally by event and/or search text -- same approach as sponsors.
  Future<void> _loadLinks() async {
    setState(() => _loadingLinks = true);
    try {
      final data = await CategoryApiService.getAllEventCategories();
      if (!mounted) return;
      setState(() => _links = data);
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingLinks = false);
    }
  }

  Future<void> _onEventFilterChanged(int? eventId) async {
    setState(() => _filterEventId = eventId);
    _applyFilters();
  }

  Future<void> _openEventFilterSearch() async {
    final result = await showDialog<EventModel>(
      context: context,
      builder: (context) => EventSearchDialog(events: _events),
    );
    if (result != null) {
      await _onEventFilterChanged(result.id);
    }
  }

  // ---------------- helpers ----------------

  String _eventNameFor(int eventId) {
    final match = _events.where((e) => e.id == eventId);
    return match.isNotEmpty ? match.first.name : 'Event #$eventId';
  }

  CategoryModel? _categoryFor(int categoryId) {
    final match = _categories.where((c) => c.id == categoryId);
    return match.isNotEmpty ? match.first : null;
  }

  void _applyFilters() {
    final q = _linkSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredLinks = _links.where((link) {
        final matchesEvent =
            _filterEventId == null || link.eventId == _filterEventId;
        final categoryName = _categoryFor(link.categoryId)?.name ?? '';
        final matchesQuery =
            q.isEmpty ||
            link.id.toString().contains(q) ||
            categoryName.toLowerCase().contains(q) ||
            _eventNameFor(link.eventId).toLowerCase().contains(q);
        return matchesEvent && matchesQuery;
      }).toList();
    });
  }

  void _filterLinks(String query) {
    _applyFilters();
  }

  Future<void> _openEventSearch() async {
    final result = await showDialog<EventModel>(
      context: context,
      builder: (context) => EventSearchDialog(events: _events),
    );
    if (result != null) {
      setState(() => _selectedEventId = result.id);
    }
  }

  Future<void> _openCategorySearch() async {
    final result = await showDialog<CategoryModel>(
      context: context,
      builder: (context) => CategorySearchDialog(categories: _categories),
    );
    if (result != null) {
      setState(() {
        _editingCategoryId = result.id;
        _categoryNameController.text = result.name;
        _selectedIconKey = result.iconPath;
      });
    }
  }

  void _clearCategorySelection() {
    setState(() {
      _editingCategoryId = null;
      _categoryNameController.clear();
      _selectedIconKey = null;
    });
  }

  Future<void> _openIconPicker() async {
    final result = await showDialog<CategoryIconOption>(
      context: context,
      builder: (context) => const IconPickerDialog(),
    );
    if (result != null) {
      setState(() => _selectedIconKey = result.key);
    }
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadLinks();
  }

  void _startEditLink(EventCategoryModel link) {
    final category = _categoryFor(link.categoryId);
    _categoryNameController.text = category?.name ?? '';

    setState(() {
      _editingEventCategoryId = link.id;
      _editingCategoryId = link.categoryId;
      _selectedEventId = link.eventId;
      _selectedIconKey = category?.iconPath;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _categoryNameController.clear();

    setState(() {
      _editingEventCategoryId = null;
      _editingCategoryId = null;
      _selectedEventId = null;
      _selectedIconKey = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteLink(EventCategoryModel link) async {
    final category = _categoryFor(link.categoryId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Remove category from event?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will remove "${category?.name ?? 'this category'}" from '
          '"${_eventNameFor(link.eventId)}". The category itself is not deleted.',
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
        await CategoryApiService.deleteEventCategoryLink(link.id);
        _loadLinks();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEventId == null) {
      _snack('Please select an event');
      return;
    }

    if (_selectedIconKey == null) {
      _snack('Please choose an icon');
      return;
    }

    final name = _categoryNameController.text.trim();
    final iconKey = _selectedIconKey!;

    // Editing a reused category changes the shared record everywhere it's
    // used, not just this event link -- confirm before overwriting it.
    if (_editingCategoryId != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Update this category?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'This changes the name/icon for '
            '"${_categoryFor(_editingCategoryId!)?.name ?? 'this category'}" '
            'everywhere it\'s used, not just this event. Continue?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.amber),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      int categoryId;

      if (_editingCategoryId == null) {
        final result = await CategoryApiService.createCategory(
          name: name,
          iconPath: iconKey,
        );
        categoryId = result['CategoryID'] as int;
        _snack(result['msg']?.toString() ?? 'Category created');
      } else {
        await CategoryApiService.updateCategory(
          categoryId: _editingCategoryId!,
          name: name,
          iconPath: iconKey,
        );
        categoryId = _editingCategoryId!;
        _snack('Category updated');
      }

      // Create or update the Event<->Category link.
      if (_editingEventCategoryId == null) {
        await CategoryApiService.linkEventCategory(
          eventId: _selectedEventId!,
          categoryId: categoryId,
        );
      } else {
        await CategoryApiService.updateEventCategoryLink(
          eventCategoryId: _editingEventCategoryId!,
          eventId: _selectedEventId!,
          categoryId: categoryId,
        );
      }

      await _loadCategories();
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
            if (_editingEventCategoryId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Category Link ID: $_editingEventCategoryId',
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
                            ? (_loadingEvents
                                  ? 'Loading...'
                                  : 'Tap to search event')
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

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loadingCategories ? null : _openCategorySearch,
                    child: InputDecorator(
                      decoration: _decoration(
                        'Use Existing Category (optional)',
                      ),
                      child: Text(
                        _editingCategoryId == null
                            ? (_loadingCategories
                                  ? 'Loading...'
                                  : 'Tap to search existing categories')
                            : (_categoryFor(_editingCategoryId!)?.name ??
                                  'Category #$_editingCategoryId'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                if (_editingCategoryId != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    tooltip: 'Clear selected category',
                    onPressed: _clearCategorySelection,
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

            TextFormField(
              controller: _categoryNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Category Name'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Category name is required'
                  : null,
            ),
            const SizedBox(height: 16),

            const Text(
              'Category Icon',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _openIconPicker,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedIconKey == null
                          ? Icons.category_outlined
                          : iconForKey(_selectedIconKey!),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedIconKey == null
                          ? 'Tap to choose an icon'
                          : labelForKey(_selectedIconKey!),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ],
                ),
              ),
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
                    : Text(
                        _editingEventCategoryId == null
                            ? 'Add Category to Event'
                            : 'Update Category',
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
                child: const Text('View / Manage Event Categories'),
              ),
            ),

            if (_editingEventCategoryId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Add New Category'),
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
                  onTap: _openEventFilterSearch,
                  child: InputDecorator(
                    decoration: _decoration('Filter by Event'),
                    child: Text(
                      _filterEventId == null
                          ? 'All Events -- tap to filter'
                          : _eventNameFor(_filterEventId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_filterEventId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  tooltip: 'Clear event filter',
                  onPressed: () => _onEventFilterChanged(null),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadLinks,
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
            controller: _linkSearchController,
            onChanged: _filterLinks,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID or category name',
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
          child: _loadingLinks
              ? const Center(child: CircularProgressIndicator())
              : _filteredLinks.isEmpty
              ? const Center(
                  child: Text(
                    'No event categories found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    itemCount: _filteredLinks.length,
                    itemBuilder: (context, index) {
                      final link = _filteredLinks[index];
                      final category = _categoryFor(link.categoryId);
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFF1E1E1E),
                            child: Icon(
                              category == null
                                  ? Icons.category_outlined
                                  : iconForKey(category.iconPath),
                              color: Colors.white70,
                              size: 24,
                            ),
                          ),
                        ),
                        title: Text(
                          category?.name ?? 'Category #${link.categoryId}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'ID: ${link.id}  •  ${_eventNameFor(link.eventId)}',
                          style: const TextStyle(color: Colors.white54),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.white70,
                              ),
                              onPressed: () => _startEditLink(link),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _confirmDeleteLink(link),
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
