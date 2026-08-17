import 'package:flutter/material.dart';
import '../services/event_api_service.dart';

class EventInfoForm extends StatefulWidget {
  const EventInfoForm({super.key});

  @override
  State<EventInfoForm> createState() => EventInfoFormState();
}

class EventInfoFormState extends State<EventInfoForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  DateTime? _startDateTime;
  DateTime? _endDateTime;

  List<EventOrganizer> _organizers = [];
  bool _loadingOrganizers = false;
  int? _selectedOrganizerId;

  List<EventModel> _events = [];
  bool _loadingEvents = false;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingEventId;

  final _eventSearchController = TextEditingController();
  List<EventModel> _filteredEvents = [];
  int? _filterOrganizerId; // null = "All Organizers"

  @override
  void initState() {
    super.initState();
    _loadOrganizers();
    _loadEvents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _eventSearchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadOrganizers() async {
    setState(() => _loadingOrganizers = true);
    try {
      final organizers = await EventApiService.getAllOrganizers();
      if (!mounted) return;
      setState(() {
        _organizers = organizers;
        if (_selectedOrganizerId != null &&
            !_organizers.any((o) => o.id == _selectedOrganizerId)) {
          _selectedOrganizerId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load organizers: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingOrganizers = false);
    }
  }

  /// Called by the dashboard's refresh button (see MainPageDashboard._appbar).
  Future<void> reloadOrganizers() => _loadOrganizers();

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final events = await EventApiService.getAllEvents();
      if (!mounted) return;
      setState(() => _events = events);
      _applyFilters();
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

  // ---------------- helpers ----------------

  String _organizerNameFor(int organizerId) {
    final match = _organizers.where((o) => o.id == organizerId);
    return match.isNotEmpty ? match.first.name : 'Organizer #$organizerId';
  }

  void _applyFilters() {
    final q = _eventSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredEvents = _events.where((event) {
        final matchesOrganizer = _filterOrganizerId == null ||
            event.organizerId == _filterOrganizerId;
        final matchesQuery = q.isEmpty ||
            event.id.toString().contains(q) ||
            event.name.toLowerCase().contains(q) ||
            event.address.toLowerCase().contains(q);
        return matchesOrganizer && matchesQuery;
      }).toList();
    });
  }

  void _filterEvents(String query) => _applyFilters();

  Future<void> _onOrganizerFilterChanged(int? organizerId) async {
    setState(() => _filterOrganizerId = organizerId);
    _applyFilters();
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadEvents();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatForApi(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}:00';

  String _formatForDisplay(DateTime? dt) {
    if (dt == null) return 'Tap to select';
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}  ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_startDateTime);
    if (picked != null) setState(() => _startDateTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_endDateTime);
    if (picked != null) setState(() => _endDateTime = picked);
  }

  // Self-contained organizer picker -- avoids depending on a SearchDialog
  // file that's typed for EventModel, not EventOrganizer.
  Future<void> _openOrganizerPicker() async {
    final result = await showDialog<EventOrganizer>(
      context: context,
      builder: (context) => _OrganizerPickerDialog(organizers: _organizers),
    );
    if (result != null) {
      setState(() => _selectedOrganizerId = result.id);
    }
  }

  Future<void> _openOrganizerFilterPicker() async {
    final result = await showDialog<EventOrganizer>(
      context: context,
      builder: (context) => _OrganizerPickerDialog(
        organizers: _organizers,
        allowClear: true,
      ),
    );
    if (result != null) {
      await _onOrganizerFilterChanged(result.id == -1 ? null : result.id);
    }
  }

  void _startEdit(EventModel event) {
    _nameController.text = event.name;
    _addressController.text = event.address;
    _descriptionController.text = event.description;
    _latitudeController.text = event.latitude.toString();
    _longitudeController.text = event.longitude.toString();

    setState(() {
      _editingEventId = event.id;
      _selectedOrganizerId = event.organizerId;
      _startDateTime = event.start;
      _endDateTime = event.end;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _addressController.clear();
    _descriptionController.clear();
    _latitudeController.clear();
    _longitudeController.clear();

    setState(() {
      _editingEventId = null;
      _selectedOrganizerId = null;
      _startDateTime = null;
      _endDateTime = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete event?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${event.name}".',
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
        await EventApiService.deleteEvent(event.id);
        _loadEvents();
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

    if (_selectedOrganizerId == null) {
      _snack('Please select an organizer');
      return;
    }
    if (_startDateTime == null) {
      _snack('Please select a start date/time');
      return;
    }
    if (_endDateTime == null) {
      _snack('Please select an end date/time');
      return;
    }
    if (_endDateTime!.isBefore(_startDateTime!)) {
      _snack('End date/time must be after the start');
      return;
    }

    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null || longitude == null) {
      _snack('Latitude and Longitude must be valid numbers');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_editingEventId == null) {
        final result = await EventApiService.createEvent(
          eventName: _nameController.text.trim(),
          eventStartingYMDT: _formatForApi(_startDateTime!),
          eventEndingYMDT: _formatForApi(_endDateTime!),
          eventAddress: _addressController.text.trim(),
          latitude: latitude,
          longitude: longitude,
          eventDescription: _descriptionController.text.trim(),
          eventOrganizerID: _selectedOrganizerId!,
        );
        _snack(result['msg']?.toString() ?? 'Event created');
      } else {
        await EventApiService.updateEvent(
          eventId: _editingEventId!,
          eventName: _nameController.text.trim(),
          eventStartingYMDT: _formatForApi(_startDateTime!),
          eventEndingYMDT: _formatForApi(_endDateTime!),
          eventAddress: _addressController.text.trim(),
          latitude: latitude,
          longitude: longitude,
          eventDescription: _descriptionController.text.trim(),
          eventOrganizerID: _selectedOrganizerId!,
        );
        _snack('Event updated');
      }

      _startCreate();
      _loadEvents();
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
            if (_editingEventId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Event ID: $_editingEventId',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Event Name'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loadingOrganizers ? null : _openOrganizerPicker,
                    child: InputDecorator(
                      decoration: _decoration('Organizer'),
                      child: Text(
                        _selectedOrganizerId == null
                            ? (_loadingOrganizers
                                ? 'Loading...'
                                : 'Tap to select organizer')
                            : _organizerNameFor(_selectedOrganizerId!),
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
                  tooltip: 'Refresh organizer list',
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStart,
                    child: InputDecorator(
                      decoration: _decoration('Start Date/Time'),
                      child: Text(
                        _formatForDisplay(_startDateTime),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickEnd,
                    child: InputDecorator(
                      decoration: _decoration('End Date/Time'),
                      child: Text(
                        _formatForDisplay(_endDateTime),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Address'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Latitude'),
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value.trim()) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Longitude'),
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value.trim()) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Description'),
              maxLines: 4,
              validator: _requiredValidator,
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
                    : Text(_editingEventId == null ? 'Create Event' : 'Update Event'),
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
                child: const Text('View / Manage Events'),
              ),
            ),

            if (_editingEventId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Event'),
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
                  onTap: _openOrganizerFilterPicker,
                  child: InputDecorator(
                    decoration: _decoration('Filter by Organizer'),
                    child: Text(
                      _filterOrganizerId == null
                          ? 'All Organizers -- tap to filter'
                          : _organizerNameFor(_filterOrganizerId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_filterOrganizerId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  tooltip: 'Clear organizer filter',
                  onPressed: () => _onOrganizerFilterChanged(null),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadEvents,
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
            controller: _eventSearchController,
            onChanged: _filterEvents,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID, name, or address',
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
          child: _loadingEvents
              ? const Center(child: CircularProgressIndicator())
              : _filteredEvents.isEmpty
                  ? const Center(
                      child: Text(
                        'No events found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: _filteredEvents.length,
                        itemBuilder: (context, index) {
                          final event = _filteredEvents[index];
                          return ListTile(
                            title: Text(
                              event.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${event.id}  •  ${_organizerNameFor(event.organizerId)}  •  '
                              '${_formatForDisplay(event.start)}  →  ${_formatForDisplay(event.end)}',
                              style: const TextStyle(color: Colors.white54),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white70),
                                  onPressed: () => _startEdit(event),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _confirmDeleteEvent(event),
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

/// Lightweight searchable organizer picker. Kept private to this file since
/// it's only used here -- the existing SearchDialog is typed for EventModel.
class _OrganizerPickerDialog extends StatefulWidget {
  final List<EventOrganizer> organizers;
  final bool allowClear;

  const _OrganizerPickerDialog({
    required this.organizers,
    this.allowClear = false,
  });

  @override
  State<_OrganizerPickerDialog> createState() => _OrganizerPickerDialogState();
}

class _OrganizerPickerDialogState extends State<_OrganizerPickerDialog> {
  final _searchController = TextEditingController();
  late List<EventOrganizer> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.organizers;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.organizers.where((o) {
        return q.isEmpty ||
            o.name.toLowerCase().contains(q) ||
            o.id.toString().contains(q);
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
                  hintText: 'Search organizers',
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
                        'No organizers found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      children: [
                        if (widget.allowClear)
                          ListTile(
                            leading: const Icon(Icons.clear, color: Colors.white70),
                            title: const Text(
                              'All Organizers',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              EventOrganizer(
                                id: -1,
                                name: 'All Organizers',
                                createdByAccountId: 0,
                              ),
                            ),
                          ),
                        for (final organizer in _filtered)
                          ListTile(
                            title: Text(
                              organizer.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${organizer.id}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () => Navigator.pop(context, organizer),
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
