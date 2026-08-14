import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../map/location_picker_page.dart';
import '../services/event_api_service.dart';
import './SearchDialog/organizer_search_dialog.dart';

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

  DateTime? _startDateTime;
  DateTime? _endDateTime;
  LatLng? _selectedLocation;

  List<EventOrganizer> _organizers = [];
  int? _selectedOrganizerId;
  bool _loadingOrganizers = false;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingEventId;

  List<EventModel> _events = [];
  bool _loadingEvents = false;
  final _eventSearchController = TextEditingController();
  List<EventModel> _filteredEvents = [];

  @override
  void initState() {
    super.initState();
    _loadOrganizers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _eventSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final events = await EventApiService.getAllEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _filteredEvents = events;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  void _filterEvents(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredEvents = _events.where((e) {
        return e.name.toLowerCase().contains(q) || e.id.toString().contains(q);
      }).toList();
    });
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadEvents();
  }

  void _startEdit(EventModel event) {
    _nameController.text = event.name;
    _addressController.text = event.address;
    _descriptionController.text = event.description;
    setState(() {
      _editingEventId = event.id;
      _startDateTime = event.start;
      _endDateTime = event.end;
      _selectedLocation = LatLng(event.latitude, event.longitude);
      _selectedOrganizerId = event.organizerId;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _addressController.clear();
    _descriptionController.clear();
    setState(() {
      _editingEventId = null;
      _startDateTime = null;
      _endDateTime = null;
      _selectedLocation = null;
      _selectedOrganizerId = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete event?',
          style: TextStyle(color: Colors.white),
        ),
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

  Future<void> _openOrganizerSearch() async {
    final result = await showDialog<EventOrganizer>(
      context: context,
      builder: (context) => OrganizerSearchDialog(organizers: _organizers),
    );
    if (result != null) {
      setState(() => _selectedOrganizerId = result.id);
    }
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load organizers: $e')));
    } finally {
      if (mounted) setState(() => _loadingOrganizers = false);
    }
  }

  Future<void> reloadOrganizers() => _loadOrganizers();

  Future<void> _pickDateTime({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startDateTime = combined;
      } else {
        _endDateTime = combined;
      }
    });
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}-'
        '${dt.hour.toString().padLeft(2, '0')}-'
        '${dt.minute.toString().padLeft(2, '0')}-00';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDateTime == null || _endDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end date/time')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a location on the map')),
      );
      return;
    }
    if (_selectedOrganizerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an organizer')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_editingEventId == null) {
        final result = await EventApiService.createEvent(
          eventName: _nameController.text.trim(),
          eventStartingYMDT: _formatDateTime(_startDateTime!),
          eventEndingYMDT: _formatDateTime(_endDateTime!),
          eventAddress: _addressController.text.trim(),
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          eventDescription: _descriptionController.text.trim(),
          eventOrganizerID: _selectedOrganizerId!,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['msg']?.toString() ?? 'Event created')),
        );
      } else {
        await EventApiService.updateEvent(
          eventId: _editingEventId!,
          eventName: _nameController.text.trim(),
          eventStartingYMDT: _formatDateTime(_startDateTime!),
          eventEndingYMDT: _formatDateTime(_endDateTime!),
          eventAddress: _addressController.text.trim(),
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          eventDescription: _descriptionController.text.trim(),
          eventOrganizerID: _selectedOrganizerId!,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event updated')));
      }

      _startCreate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _pickDateTime(isStart: true),
              child: InputDecorator(
                decoration: _decoration('Event Start'),
                child: Text(
                  _startDateTime == null
                      ? 'Select date & time'
                      : _formatDateTime(_startDateTime!),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _pickDateTime(isStart: false),
              child: InputDecorator(
                decoration: _decoration('Event End'),
                child: Text(
                  _endDateTime == null
                      ? 'Select date & time'
                      : _formatDateTime(_endDateTime!),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Event Address'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () async {
                final result = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LocationPickerPage(initialLocation: _selectedLocation),
                  ),
                );
                if (result != null) {
                  setState(() => _selectedLocation = result);
                }
              },
              child: InputDecorator(
                decoration: _decoration('Event Location'),
                child: Text(
                  _selectedLocation == null
                      ? 'Tap to pick on map'
                      : 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                            'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Event Description'),
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                                  : 'Tap to search organizer')
                            : _organizers
                                  .firstWhere(
                                    (o) => o.id == _selectedOrganizerId,
                                  )
                                  .name,
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
                        _editingEventId == null
                            ? 'Create Event'
                            : 'Update Event',
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _eventSearchController,
                  onChanged: _filterEvents,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by ID or event name',
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
              : ListView.builder(
                  itemCount: _filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = _filteredEvents[index];
                    return ListTile(
                      title: Text(
                        event.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'ID: ${event.id}  •  ${event.address}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () => _startEdit(event),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDeleteEvent(event),
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
