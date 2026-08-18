import 'package:flutter/material.dart';
import '../services/orders_api_service.dart';
import '../services/ticket_attendence_api_service.dart';
import '../services/ticket_type_api_service.dart';
import '../services/event_api_service.dart';

class TicketAttendenceForm extends StatefulWidget {
  const TicketAttendenceForm({super.key});

  @override
  State<TicketAttendenceForm> createState() => TicketAttendenceFormState();
}

class TicketAttendenceFormState extends State<TicketAttendenceForm> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  List<OrderModel> _orders = [];
  bool _loadingOrders = false;
  int? _selectedOrderId;

  List<TicketTypeModel> _ticketTypes = [];
  List<EventModel> _events = [];
  bool _loadingTicketTypes = false;
  TicketTypeModel? _selectedTicketType;
  int? _selectedTicketTypeId;

  List<TicketAttendeeModel> _attendees = [];
  bool _loadingAttendees = false;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingAttendeeId;

  final _attendeeSearchController = TextEditingController();
  List<TicketAttendeeModel> _filteredAttendees = [];
  int? _filterOrderId; // null = "All Orders"

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadAttendees();
    _loadTicketTypesAndEvents();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _attendeeSearchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final orders = await OrdersApiService.getAllOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        if (_selectedOrderId != null &&
            !_orders.any((o) => o.id == _selectedOrderId)) {
          _selectedOrderId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load orders: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> reloadOrders() => _loadOrders();

  Future<void> _loadTicketTypesAndEvents() async {
    setState(() => _loadingTicketTypes = true);
    try {
      final ticketTypes = await TicketTypeApiService.getAllTicketTypes();
      final events = await EventApiService.getAllEvents();
      if (!mounted) return;
      setState(() {
        _ticketTypes = ticketTypes;
        _events = events;
        // If we're editing and the ticket type wasn't resolvable before
        // (e.g. list wasn't loaded yet), try to resolve it now.
        if (_selectedTicketType == null && _selectedTicketTypeId != null) {
          final match =
              _ticketTypes.where((t) => t.id == _selectedTicketTypeId);
          if (match.isNotEmpty) _selectedTicketType = match.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to load ticket types: $e');
    } finally {
      if (mounted) setState(() => _loadingTicketTypes = false);
    }
  }

  Future<void> reloadTicketTypes() => _loadTicketTypesAndEvents();

  Future<void> _loadAttendees() async {
    setState(() => _loadingAttendees = true);
    try {
      final attendees = await TicketAttendenceApiService.getAllTicketAttendees();
      if (!mounted) return;
      setState(() => _attendees = attendees);
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load ticket attendees: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAttendees = false);
    }
  }

  Future<void> reloadAttendees() => _loadAttendees();

  // ---------------- helpers ----------------

  String _orderLabelFor(int orderId) {
    final match = _orders.where((o) => o.id == orderId);
    return match.isNotEmpty
        ? 'Order #${match.first.id} (Account #${match.first.accountId})'
        : 'Order #$orderId';
  }

  String _eventNameFor(int eventId) {
    final match = _events.where((e) => e.id == eventId);
    return match.isNotEmpty ? match.first.name : 'Event #$eventId';
  }

  String _ticketTypeLabelFor(TicketTypeModel t) {
    return '${t.typeName} — ${_eventNameFor(t.eventId)} (#${t.id})';
  }

  /// Best-effort display label for whatever ticket type is currently
  /// selected, even if the full TicketTypeModel hasn't been resolved yet.
  String _ticketTypeDisplayLabel() {
    if (_selectedTicketType != null) {
      return _ticketTypeLabelFor(_selectedTicketType!);
    }
    if (_selectedTicketTypeId != null) {
      return 'Ticket Type #$_selectedTicketTypeId';
    }
    return _loadingTicketTypes ? 'Loading...' : 'Tap to select ticket type';
  }

  /// Nice label for a row in the attendees table, falling back to the raw
  /// ID if the ticket type list hasn't loaded / doesn't contain it.
  String _ticketTypeSummaryFor(int ticketTypeId) {
    final match = _ticketTypes.where((t) => t.id == ticketTypeId);
    if (match.isEmpty) return 'Ticket Type #$ticketTypeId';
    return _ticketTypeLabelFor(match.first);
  }

  void _applyFilters() {
    final q = _attendeeSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredAttendees = _attendees.where((attendee) {
        final matchesOrder =
            _filterOrderId == null || attendee.orderId == _filterOrderId;
        final matchesQuery = q.isEmpty ||
            attendee.id.toString().contains(q) ||
            attendee.firstName.toLowerCase().contains(q) ||
            attendee.lastName.toLowerCase().contains(q) ||
            attendee.email.toLowerCase().contains(q);
        return matchesOrder && matchesQuery;
      }).toList();
    });
  }

  void _filterAttendees(String query) => _applyFilters();

  Future<void> _onOrderFilterChanged(int? orderId) async {
    setState(() => _filterOrderId = orderId);
    _applyFilters();
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadAttendees();
  }

  Future<void> _openOrderPicker() async {
    final result = await showDialog<OrderModel>(
      context: context,
      builder: (context) => _OrderPickerDialog(orders: _orders),
    );
    if (result != null) {
      setState(() => _selectedOrderId = result.id);
    }
  }

  Future<void> _openTicketTypePicker() async {
    final result = await showDialog<TicketTypeModel>(
      context: context,
      builder: (context) => _TicketTypePickerDialog(
        ticketTypes: _ticketTypes,
        events: _events,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedTicketType = result;
        _selectedTicketTypeId = result.id;
      });
    }
  }

  Future<void> _openOrderFilterPicker() async {
    final result = await showDialog<OrderModel>(
      context: context,
      builder: (context) => _OrderPickerDialog(
        orders: _orders,
        allowClear: true,
      ),
    );
    if (result != null) {
      await _onOrderFilterChanged(result.id == -1 ? null : result.id);
    }
  }

  void _startEdit(TicketAttendeeModel attendee) {
    _firstNameController.text = attendee.firstName;
    _lastNameController.text = attendee.lastName;
    _phoneController.text = attendee.phoneNum;
    _emailController.text = attendee.email;

    final match = _ticketTypes.where((t) => t.id == attendee.ticketTypeId);

    setState(() {
      _editingAttendeeId = attendee.id;
      _selectedOrderId = attendee.orderId;
      _selectedTicketTypeId = attendee.ticketTypeId;
      _selectedTicketType = match.isNotEmpty ? match.first : null;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _firstNameController.clear();
    _lastNameController.clear();
    _phoneController.clear();
    _emailController.clear();

    setState(() {
      _editingAttendeeId = null;
      _selectedOrderId = null;
      _selectedTicketType = null;
      _selectedTicketTypeId = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteAttendee(TicketAttendeeModel attendee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete attendee?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${attendee.firstName} ${attendee.lastName}".',
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
        await TicketAttendenceApiService.deleteTicketAttendee(attendee.id);
        _loadAttendees();
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

    if (_selectedOrderId == null) {
      _snack('Please select an order');
      return;
    }

    if (_selectedTicketTypeId == null) {
      _snack('Please select a ticket type');
      return;
    }
    final ticketTypeId = _selectedTicketTypeId!;

    setState(() => _isSubmitting = true);

    try {
      if (_editingAttendeeId == null) {
        final result = await TicketAttendenceApiService.createTicketAttendee(
          ticketTypeId: ticketTypeId,
          orderId: _selectedOrderId!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNum: _phoneController.text.trim(),
          email: _emailController.text.trim(),
        );
        _snack(result['msg']?.toString() ?? 'Ticket attendee created');
      } else {
        await TicketAttendenceApiService.updateTicketAttendee(
          attendeeId: _editingAttendeeId!,
          ticketTypeId: ticketTypeId,
          orderId: _selectedOrderId!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNum: _phoneController.text.trim(),
          email: _emailController.text.trim(),
        );
        _snack('Ticket attendee updated');
      }

      _startCreate();
      _loadAttendees();
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
            if (_editingAttendeeId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Attendee ID: $_editingAttendeeId',
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
                    onTap: _loadingOrders ? null : _openOrderPicker,
                    child: InputDecorator(
                      decoration: _decoration('Order'),
                      child: Text(
                        _selectedOrderId == null
                            ? (_loadingOrders ? 'Loading...' : 'Tap to select order')
                            : _orderLabelFor(_selectedOrderId!),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadingOrders ? null : _loadOrders,
                  icon: _loadingOrders
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh order list',
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loadingTicketTypes ? null : _openTicketTypePicker,
                    child: InputDecorator(
                      decoration: _decoration('Ticket Type'),
                      child: Text(
                        _ticketTypeDisplayLabel(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _loadingTicketTypes ? null : _loadTicketTypesAndEvents,
                  icon: _loadingTicketTypes
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh ticket type list',
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                    : Text(_editingAttendeeId == null
                        ? 'Create Attendee'
                        : 'Update Attendee'),
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
                child: const Text('View / Manage Attendees'),
              ),
            ),

            if (_editingAttendeeId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Attendee'),
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
                  onTap: _openOrderFilterPicker,
                  child: InputDecorator(
                    decoration: _decoration('Filter by Order'),
                    child: Text(
                      _filterOrderId == null
                          ? 'All Orders -- tap to filter'
                          : _orderLabelFor(_filterOrderId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_filterOrderId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  tooltip: 'Clear order filter',
                  onPressed: () => _onOrderFilterChanged(null),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadAttendees,
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
            controller: _attendeeSearchController,
            onChanged: _filterAttendees,
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
          child: _loadingAttendees
              ? const Center(child: CircularProgressIndicator())
              : _filteredAttendees.isEmpty
                  ? const Center(
                      child: Text(
                        'No ticket attendees found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: _filteredAttendees.length,
                        itemBuilder: (context, index) {
                          final attendee = _filteredAttendees[index];
                          return ListTile(
                            title: Text(
                              '${attendee.firstName} ${attendee.lastName}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${attendee.id}  •  ${attendee.email}  •  '
                              '${_orderLabelFor(attendee.orderId)}  •  '
                              '${_ticketTypeSummaryFor(attendee.ticketTypeId)}',
                              style: const TextStyle(color: Colors.white54),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white70),
                                  onPressed: () => _startEdit(attendee),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _confirmDeleteAttendee(attendee),
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

/// Lightweight searchable order picker, private to this file.
class _OrderPickerDialog extends StatefulWidget {
  final List<OrderModel> orders;
  final bool allowClear;

  const _OrderPickerDialog({
    required this.orders,
    this.allowClear = false,
  });

  @override
  State<_OrderPickerDialog> createState() => _OrderPickerDialogState();
}

class _OrderPickerDialogState extends State<_OrderPickerDialog> {
  final _searchController = TextEditingController();
  late List<OrderModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.orders;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.orders.where((o) {
        return q.isEmpty ||
            o.id.toString().contains(q) ||
            o.accountId.toString().contains(q);
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
                  hintText: 'Search orders by ID or account ID',
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
                        'No orders found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      children: [
                        if (widget.allowClear)
                          ListTile(
                            leading: const Icon(Icons.clear, color: Colors.white70),
                            title: const Text(
                              'All Orders',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              OrderModel(id: -1, accountId: 0, paymentTypeId: 0),
                            ),
                          ),
                        for (final order in _filtered)
                          ListTile(
                            title: Text(
                              'Order #${order.id}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Account #${order.accountId}  •  Payment Type #${order.paymentTypeId}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () => Navigator.pop(context, order),
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

/// Searchable ticket type picker, private to this file.
///
/// Matches on ticket type name, ticket type ID, event name, or event ID —
/// so the caller can look a ticket type up either by its own identity or
/// by which event it belongs to.
class _TicketTypePickerDialog extends StatefulWidget {
  final List<TicketTypeModel> ticketTypes;
  final List<EventModel> events;

  const _TicketTypePickerDialog({
    required this.ticketTypes,
    required this.events,
  });

  @override
  State<_TicketTypePickerDialog> createState() =>
      _TicketTypePickerDialogState();
}

class _TicketTypePickerDialogState extends State<_TicketTypePickerDialog> {
  final _searchController = TextEditingController();
  late List<TicketTypeModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.ticketTypes;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _eventNameFor(int eventId) {
    final match = widget.events.where((e) => e.id == eventId);
    return match.isNotEmpty ? match.first.name : 'Event #$eventId';
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.ticketTypes.where((t) {
        if (q.isEmpty) return true;
        final eventName = _eventNameFor(t.eventId).toLowerCase();
        return t.typeName.toLowerCase().contains(q) ||
            t.id.toString().contains(q) ||
            t.eventId.toString().contains(q) ||
            eventName.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: SizedBox(
        width: 420,
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
                  hintText:
                      'Search by ticket type / ID or event name / ID',
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
              child: widget.ticketTypes.isEmpty
                  ? const Center(
                      child: Text(
                        'No ticket types loaded',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No ticket types found',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final ticketType in _filtered)
                              ListTile(
                                title: Text(
                                  ticketType.typeName,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${_eventNameFor(ticketType.eventId)}  •  '
                                  'Ticket Type #${ticketType.id}  •  '
                                  'Event #${ticketType.eventId}',
                                  style:
                                      const TextStyle(color: Colors.white54),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () =>
                                    Navigator.pop(context, ticketType),
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
