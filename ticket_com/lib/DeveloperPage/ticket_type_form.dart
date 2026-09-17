import 'package:flutter/material.dart';
import '../services/event_api_service.dart';
import '../services/ticket_type_api_service.dart';
import './SearchDialog/event_search_dialog.dart';

class TicketTypeForm extends StatefulWidget {
  const TicketTypeForm({super.key});

  @override
  State<TicketTypeForm> createState() => TicketTypeFormState();
}

class TicketTypeFormState extends State<TicketTypeForm> {
  final _formKey = GlobalKey<FormState>();

  final _typeNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();

  DateTime? _saleStart;
  DateTime? _saleEnd;

  List<EventModel> _events = [];
  int? _selectedEventId;
  bool _loadingEvents = false;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingTicketTypeId;

  List<TicketTypeModel> _ticketTypes = [];
  bool _loadingTicketTypes = false;
  final _ticketTypeSearchController = TextEditingController();
  List<TicketTypeModel> _filteredTicketTypes = [];
  int? _filterEventId; // null = "All Events"

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _typeNameController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _ticketTypeSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadTicketTypes() async {
    setState(() => _loadingTicketTypes = true);
    try {
      final data = _filterEventId == null
          ? await TicketTypeApiService.getAllTicketTypes()
          : await TicketTypeApiService.getTicketTypesByEvent(_filterEventId!);
      if (!mounted) return;
      setState(() {
        _ticketTypes = data;
        _filteredTicketTypes = data;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingTicketTypes = false);
    }
  }

  Future<void> _onEventFilterChanged(int? eventId) async {
    setState(() => _filterEventId = eventId);
    _ticketTypeSearchController.clear();
    await _loadTicketTypes();
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

  Future<void> _runSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      await _loadTicketTypes();
      return;
    }
    setState(() => _loadingTicketTypes = true);
    try {
      final results = await TicketTypeApiService.searchTicketTypes(query);
      if (!mounted) return;
      setState(() => _filteredTicketTypes = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingTicketTypes = false);
    }
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadTicketTypes();
  }

  String _eventNameFor(int eventId) {
    final match = _events.where((e) => e.id == eventId);
    return match.isNotEmpty ? match.first.name : 'Event #$eventId';
  }

  void _startEdit(TicketTypeModel ticket) {
    _typeNameController.text = ticket.typeName;
    _priceController.text = ticket.priceInKip.toString();
    _capacityController.text = ticket.capacity.toString();
    setState(() {
      _editingTicketTypeId = ticket.id;
      _selectedEventId = ticket.eventId;
      _saleStart = DateTime.tryParse(_normalizeForParse(ticket.saleStart));
      _saleEnd = DateTime.tryParse(_normalizeForParse(ticket.saleEnd));
      _showingTable = false;
    });
  }

  // Backend stores dates as 'YYYY-MM-DD-HH-MM-00' (matching EventInfoForm's
  // format) -- convert back to a parseable ISO-ish string for editing.
  String _normalizeForParse(String raw) {
    final parts = raw.split('-');
    if (parts.length == 6) {
      return '${parts[0]}-${parts[1]}-${parts[2]} ${parts[3]}:${parts[4]}:${parts[5]}';
    }
    return raw;
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _typeNameController.clear();
    _priceController.clear();
    _capacityController.clear();
    setState(() {
      _editingTicketTypeId = null;
      _saleStart = null;
      _saleEnd = null;
      _selectedEventId = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteTicketType(TicketTypeModel ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete ticket type?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete "${ticket.typeName}".',
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
        await TicketTypeApiService.deleteTicketType(ticket.id);
        _loadTicketTypes();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
        _saleStart = combined;
      } else {
        _saleEnd = combined;
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

    if (_saleStart == null || _saleEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select sale start and end date/time'),
        ),
      );
      return;
    }
    if (_selectedEventId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an event')));
      return;
    }

    final price = int.tryParse(_priceController.text.trim());
    final capacity = int.tryParse(_capacityController.text.trim());
    if (price == null || capacity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price and Capacity must be numbers')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_editingTicketTypeId == null) {
        final result = await TicketTypeApiService.createTicketType(
          eventId: _selectedEventId!,
          typeName: _typeNameController.text.trim(),
          priceInKip: price,
          capacity: capacity,
          saleStart: _formatDateTime(_saleStart!),
          saleEnd: _formatDateTime(_saleEnd!),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg']?.toString() ?? 'Ticket type created'),
          ),
        );
      } else {
        await TicketTypeApiService.updateTicketType(
          ticketTypeId: _editingTicketTypeId!,
          eventId: _selectedEventId!,
          typeName: _typeNameController.text.trim(),
          priceInKip: price,
          capacity: capacity,
          saleStart: _formatDateTime(_saleStart!),
          saleEnd: _formatDateTime(_saleEnd!),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ticket type updated')));
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
            if (_editingTicketTypeId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Ticket Type ID: $_editingTicketTypeId',
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

            TextFormField(
              controller: _typeNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Type Name (e.g. VIP, Standard)'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Price (Kip)'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Capacity'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _pickDateTime(isStart: true),
              child: InputDecorator(
                decoration: _decoration('Sale Start'),
                child: Text(
                  _saleStart == null
                      ? 'Select date & time'
                      : _formatDateTime(_saleStart!),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _pickDateTime(isStart: false),
              child: InputDecorator(
                decoration: _decoration('Sale End'),
                child: Text(
                  _saleEnd == null
                      ? 'Select date & time'
                      : _formatDateTime(_saleEnd!),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
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
                        _editingTicketTypeId == null
                            ? 'Create Ticket Type'
                            : 'Update Ticket Type',
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
                child: const Text('View / Manage Ticket Types'),
              ),
            ),

            if (_editingTicketTypeId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Ticket Type'),
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
                onPressed: _loadTicketTypes,
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
            controller: _ticketTypeSearchController,
            onSubmitted: _runSearch,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'Search by name, price, capacity, or date -- press Enter',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Colors.white54, size: 18),
                onPressed: () => _runSearch(_ticketTypeSearchController.text),
              ),
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
          child: _loadingTicketTypes
              ? const Center(child: CircularProgressIndicator())
              : _filteredTicketTypes.isEmpty
              ? const Center(
                  child: Text(
                    'No ticket types found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredTicketTypes.length,
                  itemBuilder: (context, index) {
                    final ticket = _filteredTicketTypes[index];
                    return ListTile(
                      title: Text(
                        ticket.typeName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'ID: ${ticket.id}  •  ${_eventNameFor(ticket.eventId)}  •  '
                        '${ticket.priceInKip} Kip  •  Cap: ${ticket.capacity}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () => _startEdit(ticket),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDeleteTicketType(ticket),
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
