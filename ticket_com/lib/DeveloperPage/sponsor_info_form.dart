import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/sponser_models.dart';
import '../services/sponser_api_service.dart';

/// Manages sponsors only (name + logo). Does NOT touch event<->sponsor
/// linking -- that stays in the existing event_sponser_form.dart.
class SponsorInfoForm extends StatefulWidget {
  const SponsorInfoForm({super.key});

  @override
  State<SponsorInfoForm> createState() => SponsorInfoFormState();
}

class SponsorInfoFormState extends State<SponsorInfoForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Uint8List? _pickedBytes;
  String? _pickedFilename;

  List<SponserModel> _sponsors = [];
  bool _loadingSponsors = false;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingSponsorId;
  String? _editingExistingLogoPath;

  final _sponsorSearchController = TextEditingController();
  List<SponserModel> _filteredSponsors = [];

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sponsorSearchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadSponsors() async {
    setState(() => _loadingSponsors = true);
    try {
      final sponsors = await SponserApiService.getAllSponsers();
      if (!mounted) return;
      setState(() => _sponsors = sponsors);
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load sponsors: $e')));
    } finally {
      if (mounted) setState(() => _loadingSponsors = false);
    }
  }

  Future<void> reloadSponsors() => _loadSponsors();

  // ---------------- helpers ----------------

  void _applyFilter() {
    final q = _sponsorSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredSponsors = _sponsors.where((s) {
        return q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            s.id.toString().contains(q);
      }).toList();
    });
  }

  void _filterSponsors(String query) => _applyFilter();

  void _openTable() {
    setState(() => _showingTable = true);
    _loadSponsors();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _pickedFilename = picked.name;
    });
  }

  void _startEdit(SponserModel sponsor) {
    _nameController.text = sponsor.name;
    _pickedBytes = null;
    _pickedFilename = null;

    setState(() {
      _editingSponsorId = sponsor.id;
      _editingExistingLogoPath = sponsor.logoPath;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _pickedBytes = null;
    _pickedFilename = null;

    setState(() {
      _editingSponsorId = null;
      _editingExistingLogoPath = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteSponsor(SponserModel sponsor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete sponsor?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${sponsor.name}".',
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
        await SponserApiService.deleteSponser(sponsor.id);
        _loadSponsors();
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

    final name = _nameController.text.trim();

    if (_editingSponsorId == null && _pickedBytes == null) {
      _snack('Please choose a logo image');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_editingSponsorId == null) {
        final result = await SponserApiService.uploadSponser(
          bytes: _pickedBytes!,
          filename: _pickedFilename ?? 'logo.jpg',
          name: name,
        );
        _snack(result['msg']?.toString() ?? 'Sponsor created');
      } else {
        final result = await SponserApiService.replaceSponserLogo(
          sponserId: _editingSponsorId!,
          name: name,
          bytes: _pickedBytes,
          filename: _pickedFilename,
        );
        _snack(result['msg']?.toString() ?? 'Sponsor updated');
      }

      _startCreate();
      _loadSponsors();
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
            if (_editingSponsorId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Sponsor ID: $_editingSponsorId',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            Center(child: _buildLogoPicker()),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Sponsor Name'),
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
                    : Text(_editingSponsorId == null
                        ? 'Create Sponsor'
                        : 'Update Sponsor'),
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
                child: const Text('View / Manage Sponsors'),
              ),
            ),

            if (_editingSponsorId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Sponsor'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildLogoPreview(),
      ),
    );
  }

  Widget _buildLogoPreview() {
    if (_pickedBytes != null) {
      return Image.memory(_pickedBytes!, fit: BoxFit.cover);
    }
    if (_editingExistingLogoPath != null) {
      return Image.network(
        SponserApiService.fullImageUrl(_editingExistingLogoPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _logoPlaceholder(),
      );
    }
    return _logoPlaceholder();
  }

  Widget _logoPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: Colors.white54, size: 32),
          SizedBox(height: 6),
          Text(
            'Tap to choose logo',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
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
              const Expanded(
                child: Text(
                  'Sponsors',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadSponsors,
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
            controller: _sponsorSearchController,
            onChanged: _filterSponsors,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or ID',
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
          child: _loadingSponsors
              ? const Center(child: CircularProgressIndicator())
              : _filteredSponsors.isEmpty
                  ? const Center(
                      child: Text(
                        'No sponsors found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: _filteredSponsors.length,
                        itemBuilder: (context, index) {
                          final sponsor = _filteredSponsors[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Image.network(
                                  SponserApiService.fullImageUrl(sponsor.logoPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      Container(
                                    color: const Color(0xFF2A2A2A),
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.white38,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              sponsor.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${sponsor.id}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white70),
                                  onPressed: () => _startEdit(sponsor),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _confirmDeleteSponsor(sponsor),
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
