import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../services/event_organizer_api_service.dart';
import './SearchDialog/event_organizer_search_dialog.dart';
import './SearchDialog/account_search_dialog.dart';
import './square_crop_page.dart';

class EventOrganizerForm extends StatefulWidget {
  const EventOrganizerForm({super.key});

  @override
  State<EventOrganizerForm> createState() => EventOrganizerFormState();
}

class EventOrganizerFormState extends State<EventOrganizerForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  // Verified-account picker (replaces manual "Created By Account ID" entry).
  List<VerifiedAccount> _accounts = [];
  bool _loadingAccounts = false;
  int? _selectedAccountId;

  // A newly picked (and possibly cropped) logo, held as bytes.
  Uint8List? _pickedLogoBytes;
  String? _pickedLogoName;
  // The logo path already stored on the server, shown as a preview while
  // editing if the user hasn't picked a replacement.
  String? _existingLogoPath;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingOrganizerId;

  List<EventOrganizer> _organizers = [];
  bool _loadingOrganizers = false;

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final data = await EventOrganizerApiService.getVerifiedAccounts();
      if (!mounted) return;
      setState(() => _accounts = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  /// Display label for a picked account. Falls back to a bare ID if the
  /// account isn't in the currently loaded list yet (e.g. right after
  /// jumping into "edit" before the accounts have finished loading).
  String _accountLabelFor(int accountId) {
    final match = _accounts.where((a) => a.id == accountId);
    if (match.isEmpty) return 'Account #$accountId';
    final a = match.first;
    return a.fullName.isEmpty
        ? 'Account #${a.id}'
        : '${a.fullName} (ID: ${a.id})';
  }

  Future<void> _openAccountSearch() async {
    if (_accounts.isEmpty) {
      await _loadAccounts();
    }
    if (!mounted) return;
    final result = await showDialog<VerifiedAccount>(
      context: context,
      builder: (context) => AccountSearchDialog(accounts: _accounts),
    );
    if (result != null) {
      setState(() => _selectedAccountId = result.id);
    }
  }

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

  // ---------------- logo picking ----------------

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded != null && decoded.width != decoded.height) {
      // Not square -- send the user to crop it before we accept it.
      if (!mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => SquareCropPage(bytes: bytes)),
      );
      if (cropped == null) return; // user cancelled the crop
      setState(() {
        _pickedLogoBytes = cropped;
        _pickedLogoName = picked.name;
      });
    } else {
      setState(() {
        _pickedLogoBytes = bytes;
        _pickedLogoName = picked.name;
      });
    }
  }

  Widget _buildLogoPreview() {
    Widget child;
    if (_pickedLogoBytes != null) {
      child = Image.memory(_pickedLogoBytes!, fit: BoxFit.cover);
    } else if (_existingLogoPath != null && _existingLogoPath!.isNotEmpty) {
      child = Image.network(
        EventOrganizerApiService.fullImageUrl(_existingLogoPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white38),
        ),
      );
    } else {
      child = const Center(
        child: Icon(Icons.business_outlined, color: Colors.white38, size: 40),
      );
    }

    // Square preview since the stored logo is always square.
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 160,
        width: 160,
        color: const Color(0xFF1E1E1E),
        child: child,
      ),
    );
  }

  // ---------------- form actions ----------------

  void _startEdit(EventOrganizer org) {
    _nameController.text = org.name;
    _descriptionController.text = org.description ?? '';
    setState(() {
      _editingOrganizerId = org.id;
      _selectedAccountId = org.createdByAccountId;
      _existingLogoPath = org.logoPath;
      _pickedLogoBytes = null;
      _pickedLogoName = null;
      _showingTable = false;
    });
    // Make sure we have the account list loaded so the picker shows a real
    // name instead of just "Account #<id>".
    if (_accounts.isEmpty) {
      _loadAccounts();
    }
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _descriptionController.clear();
    setState(() {
      _editingOrganizerId = null;
      _selectedAccountId = null;
      _existingLogoPath = null;
      _pickedLogoBytes = null;
      _pickedLogoName = null;
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

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a verified account')),
      );
      return;
    }
    final createdByAccountId = _selectedAccountId!;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      if (_editingOrganizerId == null) {
        // New organizer: logo is mandatory, there's nothing to point
        // EventOrganizerLogoPath at otherwise.
        if (_pickedLogoBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please upload an organizer logo')),
          );
          return;
        }
        final result = await EventOrganizerApiService.uploadOrganizer(
          bytes: _pickedLogoBytes!,
          filename: _pickedLogoName ?? 'logo.jpg',
          name: name,
          createdByAccountId: createdByAccountId,
          description: description,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg']?.toString() ?? 'Organizer created'),
          ),
        );
      } else if (_pickedLogoBytes != null) {
        // Editing and picked a replacement file.
        final result = await EventOrganizerApiService.replaceOrganizerLogo(
          organizerId: _editingOrganizerId!,
          name: name,
          createdByAccountId: createdByAccountId,
          description: description,
          bytes: _pickedLogoBytes!,
          filename: _pickedLogoName ?? 'logo.jpg',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg']?.toString() ?? 'Organizer updated'),
          ),
        );
      } else {
        // Editing, no new file picked: just update fields, keep the
        // existing logo path.
        await EventOrganizerApiService.updateOrganizer(
          id: _editingOrganizerId!,
          name: name,
          logoPath: _existingLogoPath ?? '',
          createdByAccountId: createdByAccountId,
          description: description,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Organizer updated')));
      }

      await _loadOrganizers();
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

            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Organizer Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            const Text(
              'Organizer Logo (must be square)',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            _buildLogoPreview(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(
                Icons.photo_library_outlined,
                color: Colors.white,
              ),
              label: Text(
                _pickedLogoBytes == null && _existingLogoPath == null
                    ? 'Choose Logo'
                    : 'Choose Different Logo',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "If the picked image isn't square, you'll be asked to crop it before it's used.",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loadingAccounts ? null : _openAccountSearch,
                    child: InputDecorator(
                      decoration: _decoration('Created By (Verified Account)'),
                      child: Text(
                        _selectedAccountId == null
                            ? (_loadingAccounts
                                  ? 'Loading...'
                                  : 'Tap to search verified accounts')
                            : _accountLabelFor(_selectedAccountId!),
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
                  tooltip: 'Refresh verified accounts',
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Only accounts with an accepted identity verification are shown.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
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
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: (org.logoPath == null || org.logoPath!.isEmpty)
                              ? Container(
                                  color: const Color(0xFF1E1E1E),
                                  child: const Icon(
                                    Icons.business_outlined,
                                    color: Colors.white38,
                                    size: 20,
                                  ),
                                )
                              : Image.network(
                                  EventOrganizerApiService.fullImageUrl(
                                    org.logoPath!,
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      Container(
                                        color: const Color(0xFF1E1E1E),
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white38,
                                          size: 20,
                                        ),
                                      ),
                                ),
                        ),
                      ),
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
