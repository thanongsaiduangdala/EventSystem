import 'package:flutter/material.dart';
import '../services/event_organizer_api_service.dart';
import './SearchDialog/event_organizer_search_dialog.dart';

class EventOrganizerForm extends StatefulWidget {
  const EventOrganizerForm({super.key});

  @override
  State<EventOrganizerForm> createState() => EventOrganizerFormState();
}

class EventOrganizerFormState extends State<EventOrganizerForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _logoPathController = TextEditingController();
  final _createdByController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingOrganizerId;

  List<EventOrganizer> _organizers = [];
  bool _loadingOrganizers = false;

  @override
  void dispose() {
    _nameController.dispose();
    _logoPathController.dispose();
    _createdByController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadOrganizers() async {
    setState(() => _loadingOrganizers = true);
    try {
      final data = await EventOrganizerApiService.getAllOrganizers();
      if (!mounted) return;
      setState(() => _organizers = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingOrganizers = false);
    }
  }

  Future<void> reloadOrganizers() => _loadOrganizers();

  void _openTable() {
    setState(() => _showingTable = true);
    _loadOrganizers();
  }

  // ---------------- popup search (same OrganizerSearchDialog used app-wide) ----------------

  /// Opens the shared organizer search popup -- searches by ID or name,
  /// same as the "Filter by Event" pickers used in the other forms.
  /// Selecting a result jumps straight into editing it.
  Future<void> _openOrganizerSearch() async {
    if (_organizers.isEmpty) {
      await _loadOrganizers();
    }
    if (!mounted) return;
    final result = await showDialog<EventOrganizer>(
      context: context,
      builder: (context) => EventOrganizerSearchDialog(organizers: _organizers),
    );
    if (result != null) {
      _startEdit(result);
    }
  }

  // ---------------- form actions ----------------

  void _startEdit(EventOrganizer org) {
    _nameController.text = org.name;
    _logoPathController.text = org.logoPath ?? '';
    _createdByController.text = org.createdByAccountId.toString();
    _descriptionController.text = org.description ?? '';
    setState(() {
      _editingOrganizerId = org.id;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _logoPathController.clear();
    _createdByController.clear();
    _descriptionController.clear();
    setState(() {
      _editingOrganizerId = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteOrganizer(EventOrganizer org) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete organizer?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete "${org.name}".',
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
        await EventOrganizerApiService.deleteOrganizer(org.id);
        _loadOrganizers();
        if (_editingOrganizerId == org.id) {
          _startCreate();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final createdByAccountId = int.tryParse(_createdByController.text.trim());
    if (createdByAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Created By Account ID must be a number')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_editingOrganizerId == null) {
        final result = await EventOrganizerApiService.createOrganizer(
          name: _nameController.text.trim(),
          logoPath: _logoPathController.text.trim(),
          createdByAccountId: createdByAccountId,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg']?.toString() ?? 'Organizer created'),
          ),
        );
      } else {
        await EventOrganizerApiService.updateOrganizer(
          id: _editingOrganizerId!,
          name: _nameController.text.trim(),
          logoPath: _logoPathController.text.trim(),
          createdByAccountId: createdByAccountId,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Organizer updated')));
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
            if (_editingOrganizerId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Organizer ID: $_editingOrganizerId',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Same popup search used everywhere else (searches ID + name)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openOrganizerSearch,
                icon: const Icon(Icons.search, color: Colors.white70),
                label: const Text('Search Organizer (ID or Name)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Organizer Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _logoPathController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Logo Path / URL'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _createdByController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Created By Account ID'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (int.tryParse(v.trim()) == null) return 'Must be a number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Description (optional)'),
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
                        _editingOrganizerId == null
                            ? 'Create Event Organizer'
                            : 'Update Event Organizer',
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
                child: const Text('View / Manage Event Organizers'),
              ),
            ),

            if (_editingOrganizerId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Organizer'),
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
                  onTap: _openOrganizerSearch,
                  child: InputDecorator(
                    decoration: _decoration('Search Organizer'),
                    child: const Text(
                      'Tap to search by ID or name',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadOrganizers,
              ),
              TextButton(
                onPressed: () => setState(() => _showingTable = false),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingOrganizers
              ? const Center(child: CircularProgressIndicator())
              : _organizers.isEmpty
              ? const Center(
                  child: Text(
                    'No event organizers found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _organizers.length,
                  itemBuilder: (context, index) {
                    final org = _organizers[index];
                    return ListTile(
                      title: Text(
                        org.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'ID: ${org.id}'
                        '${org.description != null && org.description!.isNotEmpty ? '  •  ${org.description}' : ''}',
                        style: const TextStyle(color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () => _startEdit(org),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDeleteOrganizer(org),
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
