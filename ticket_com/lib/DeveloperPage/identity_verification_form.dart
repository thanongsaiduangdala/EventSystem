import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/identity_verification_api_service.dart';
import '../services/account_api_service.dart';

class IdentityVerificationForm extends StatefulWidget {
  const IdentityVerificationForm({super.key});

  @override
  State<IdentityVerificationForm> createState() =>
      IdentityVerificationFormState();
}

class IdentityVerificationFormState extends State<IdentityVerificationForm> {
  final _formKey = GlobalKey<FormState>();

  final _idNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _documentPathController = TextEditingController();

  List<AccountModel> _accounts = [];
  bool _loadingAccounts = false;

  List<VerificationTypeModel> _types = [];
  bool _loadingTypes = false;

  List<VerificationStatusModel> _statuses = [];
  bool _loadingStatuses = false;

  List<IdentityVerificationModel> _verifications = [];
  bool _loadingVerifications = false;

  int? _selectedAccountId;
  int? _selectedTypeId;
  int? _selectedStatusId;
  int? _selectedReviewerAccountId;

  DateTime? _dateOfBirth;
  DateTime _submittedAt = DateTime.now();
  DateTime? _reviewedAt;

  bool _isSubmitting = false;
  bool _showingTable = false;
  int? _editingVerificationId;

  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingDocument = false;

  final _searchController = TextEditingController();
  List<IdentityVerificationModel> _filteredVerifications = [];
  int? _filterStatusId; // null = "All Statuses"

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadTypes();
    _loadStatuses();
    _loadVerifications();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _fullNameController.dispose();
    _dobController.dispose();
    _documentPathController.dispose();
    _searchController.dispose();
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
      _snack('Failed to load accounts: $e');
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _loadTypes() async {
    setState(() => _loadingTypes = true);
    try {
      final types = await IdentityVerificationApiService.getAllTypes();
      if (!mounted) return;
      setState(() => _types = types);
    } catch (e) {
      _snack('Failed to load verification types: $e');
    } finally {
      if (mounted) setState(() => _loadingTypes = false);
    }
  }

  Future<void> _loadStatuses() async {
    setState(() => _loadingStatuses = true);
    try {
      final statuses = await IdentityVerificationApiService.getAllStatuses();
      if (!mounted) return;
      setState(() => _statuses = statuses);
    } catch (e) {
      _snack('Failed to load verification statuses: $e');
    } finally {
      if (mounted) setState(() => _loadingStatuses = false);
    }
  }

  Future<void> _loadVerifications() async {
    setState(() => _loadingVerifications = true);
    try {
      final rows = await IdentityVerificationApiService.getAllVerifications();
      if (!mounted) return;
      setState(() => _verifications = rows);
      _applyFilters();
    } catch (e) {
      _snack('Failed to load identity verifications: $e');
    } finally {
      if (mounted) setState(() => _loadingVerifications = false);
    }
  }

  /// Called by the dashboard's refresh button, mirroring reloadOrganizers().
  Future<void> reloadVerifications() => _loadVerifications();

  // ---------------- helpers ----------------

  String _accountLabel(int accountId) {
    final match = _accounts.where((a) => a.id == accountId);
    if (match.isEmpty) return 'Account #$accountId';
    final a = match.first;
    return '${a.firstName} ${a.lastName} (#${a.id})';
  }

  String _typeNameFor(int typeId) {
    final match = _types.where((t) => t.id == typeId);
    return match.isNotEmpty ? match.first.idType : 'Type #$typeId';
  }

  String _statusNameFor(int statusId) {
    final match = _statuses.where((s) => s.id == statusId);
    return match.isNotEmpty ? match.first.statusName : 'Status #$statusId';
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  DateTime? _tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredVerifications = _verifications.where((v) {
        final matchesStatus =
            _filterStatusId == null || v.verificationStatusId == _filterStatusId;
        final matchesQuery = q.isEmpty ||
            v.id.toString().contains(q) ||
            v.accountId.toString().contains(q) ||
            v.fullNameOnId.toLowerCase().contains(q);
        return matchesStatus && matchesQuery;
      }).toList();
    });
  }

  void _filterVerifications(String query) => _applyFilters();

  void _onStatusFilterChanged(int? statusId) {
    setState(() => _filterStatusId = statusId);
    _applyFilters();
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadVerifications();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------- pickers ----------------

  Future<void> _openAccountPicker({required bool forReviewer}) async {
    final result = await showDialog<AccountModel>(
      context: context,
      builder: (context) => _AccountPickerDialog(
        accounts: _accounts,
        allowClear: forReviewer,
      ),
    );
    if (result == null) return;
    setState(() {
      if (forReviewer) {
        _selectedReviewerAccountId = result.id == -1 ? null : result.id;
      } else {
        _selectedAccountId = result.id;
      }
    });
  }

  Future<void> _openTypePicker() async {
    final result = await showDialog<VerificationTypeModel>(
      context: context,
      builder: (context) => _VerificationTypePickerDialog(types: _types),
    );
    if (result != null) {
      setState(() => _selectedTypeId = result.id);
    }
    _loadTypes();
  }

  Future<void> _openStatusPicker({bool allowClear = false}) async {
    final result = await showDialog<VerificationStatusModel>(
      context: context,
      builder: (context) => _VerificationStatusPickerDialog(
        statuses: _statuses,
        allowClear: allowClear,
      ),
    );
    if (result != null) {
      if (allowClear) {
        _onStatusFilterChanged(result.id == -1 ? null : result.id);
      } else {
        setState(() => _selectedStatusId = result.id);
      }
    }
    _loadStatuses();
  }

  Future<void> _pickDocumentImage(ImageSource source) async {
    XFile? picked;
    try {
      picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
    } catch (e) {
      _snack('Could not open camera/gallery: $e');
      return;
    }
    if (picked == null) return;

    setState(() => _uploadingDocument = true);
    try {
      final bytes = await picked.readAsBytes();
      final filename = picked.name.trim().isNotEmpty ? picked.name : 'document.jpg';
      final path = await IdentityVerificationApiService.uploadDocumentImage(
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) return;
      setState(() => _documentPathController.text = path);
      _snack('Document image uploaded');
    } catch (e) {
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingDocument = false);
    }
  }

  Future<void> _chooseDocumentImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.white70),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      await _pickDocumentImage(source);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text = _fmtDate(picked);
      });
    }
  }

  Future<void> _pickSubmittedAt() async {
    final picked = await _pickDateTime(_submittedAt);
    if (picked != null) setState(() => _submittedAt = picked);
  }

  Future<void> _pickReviewedAt() async {
    final picked = await _pickDateTime(_reviewedAt ?? DateTime.now());
    if (picked != null) setState(() => _reviewedAt = picked);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null) return null;
    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ---------------- create / edit / delete ----------------

  void _startEdit(IdentityVerificationModel v) {
    _idNumberController.text = v.idNumberEncrypted;
    _fullNameController.text = v.fullNameOnId;
    _documentPathController.text = v.documentImagePath;

    final dob = _tryParse(v.dateOfBirth);
    final submitted = _tryParse(v.submittedAtYmdt) ?? DateTime.now();
    final reviewed = _tryParse(v.reviewedAtYmdt);

    setState(() {
      _editingVerificationId = v.id;
      _selectedAccountId = v.accountId;
      _selectedTypeId = v.verificationTypeId;
      _selectedStatusId = v.verificationStatusId;
      _selectedReviewerAccountId = v.reviewedByAccountId;
      _dateOfBirth = dob;
      _dobController.text = dob != null ? _fmtDate(dob) : v.dateOfBirth;
      _submittedAt = submitted;
      _reviewedAt = reviewed;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _idNumberController.clear();
    _fullNameController.clear();
    _dobController.clear();
    _documentPathController.clear();

    setState(() {
      _editingVerificationId = null;
      _selectedAccountId = null;
      _selectedTypeId = null;
      _selectedStatusId = null;
      _selectedReviewerAccountId = null;
      _dateOfBirth = null;
      _submittedAt = DateTime.now();
      _reviewedAt = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDelete(IdentityVerificationModel v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete verification record?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete verification #${v.id} '
          'for "${v.fullNameOnId}".',
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
        await IdentityVerificationApiService.deleteVerification(v.id);
        _loadVerifications();
      } catch (e) {
        _snack('Error: $e');
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAccountId == null) {
      _snack('Please select an account');
      return;
    }
    if (_selectedTypeId == null) {
      _snack('Please select a verification type');
      return;
    }
    if (_selectedStatusId == null) {
      _snack('Please select a verification status');
      return;
    }
    if (_dateOfBirth == null) {
      _snack('Please select a date of birth');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_editingVerificationId == null) {
        final result = await IdentityVerificationApiService.createVerification(
          accountId: _selectedAccountId!,
          verificationTypeId: _selectedTypeId!,
          idNumberEncrypted: _idNumberController.text.trim(),
          fullNameOnId: _fullNameController.text.trim(),
          dateOfBirth: _fmtDate(_dateOfBirth!),
          documentImagePath: _documentPathController.text.trim(),
          verificationStatusId: _selectedStatusId!,
          reviewedByAccountId: _selectedReviewerAccountId,
          submittedAtYmdt: _fmtDateTime(_submittedAt),
          reviewedAtYmdt: _reviewedAt != null ? _fmtDateTime(_reviewedAt!) : null,
        );
        _snack(result['msg']?.toString() ?? 'Identity verification created');
      } else {
        await IdentityVerificationApiService.updateVerification(
          verificationId: _editingVerificationId!,
          accountId: _selectedAccountId!,
          verificationTypeId: _selectedTypeId!,
          idNumberEncrypted: _idNumberController.text.trim(),
          fullNameOnId: _fullNameController.text.trim(),
          dateOfBirth: _fmtDate(_dateOfBirth!),
          documentImagePath: _documentPathController.text.trim(),
          verificationStatusId: _selectedStatusId!,
          reviewedByAccountId: _selectedReviewerAccountId,
          submittedAtYmdt: _fmtDateTime(_submittedAt),
          reviewedAtYmdt: _reviewedAt != null ? _fmtDateTime(_reviewedAt!) : null,
        );
        _snack('Identity verification updated');
      }

      _startCreate();
      _loadVerifications();
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
            if (_editingVerificationId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Verification ID: $_editingVerificationId',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            _pickerField(
              label: 'Account',
              value: _selectedAccountId == null
                  ? null
                  : _accountLabel(_selectedAccountId!),
              loading: _loadingAccounts,
              onTap: () => _openAccountPicker(forReviewer: false),
              onRefresh: _loadAccounts,
            ),
            const SizedBox(height: 16),

            _pickerField(
              label: 'Verification Type',
              value:
                  _selectedTypeId == null ? null : _typeNameFor(_selectedTypeId!),
              loading: _loadingTypes,
              onTap: _openTypePicker,
              onRefresh: _loadTypes,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _idNumberController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('ID Number (stored encrypted)'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _fullNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Full Name on ID'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: _pickDateOfBirth,
              child: InputDecorator(
                decoration: _decoration('Date of Birth'),
                child: Text(
                  _dobController.text.isEmpty
                      ? 'Tap to select date'
                      : _dobController.text,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildDocumentImagePicker(),
            const SizedBox(height: 16),

            _pickerField(
              label: 'Verification Status',
              value: _selectedStatusId == null
                  ? null
                  : _statusNameFor(_selectedStatusId!),
              loading: _loadingStatuses,
              onTap: () => _openStatusPicker(),
              onRefresh: _loadStatuses,
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _pickerField(
                    label: 'Reviewed By (optional)',
                    value: _selectedReviewerAccountId == null
                        ? null
                        : _accountLabel(_selectedReviewerAccountId!),
                    loading: _loadingAccounts,
                    onTap: () => _openAccountPicker(forReviewer: true),
                    onRefresh: _loadAccounts,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: _pickSubmittedAt,
              child: InputDecorator(
                decoration: _decoration('Submitted At'),
                child: Text(
                  _fmtDateTime(_submittedAt),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickReviewedAt,
                    child: InputDecorator(
                      decoration: _decoration('Reviewed At (optional)'),
                      child: Text(
                        _reviewedAt == null
                            ? 'Tap to select'
                            : _fmtDateTime(_reviewedAt!),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                if (_reviewedAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    tooltip: 'Clear reviewed-at',
                    onPressed: () => setState(() => _reviewedAt = null),
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
                    : Text(_editingVerificationId == null
                        ? 'Create Verification'
                        : 'Update Verification'),
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
                child: const Text('View / Manage Verifications'),
              ),
            ),

            if (_editingVerificationId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Record'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentImagePicker() {
    final hasPath = _documentPathController.text.trim().isNotEmpty;
    final previewUrl = hasPath
        ? IdentityVerificationApiService.fullImageUrl(_documentPathController.text.trim())
        : null;

    return FormField<String>(
      initialValue: _documentPathController.text,
      validator: (_) => _requiredValidator(_documentPathController.text),
      builder: (fieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Document Image', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 180,
                width: double.infinity,
                color: Colors.white10,
                child: _uploadingDocument
                    ? const Center(child: CircularProgressIndicator())
                    : previewUrl == null
                        ? const Center(
                            child: Icon(Icons.image_outlined,
                                color: Colors.white38, size: 48),
                          )
                        : Image.network(
                            previewUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.white38, size: 48),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadingDocument ? null : _chooseDocumentImageSource,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(hasPath ? 'Replace Image' : 'Take Photo / Upload'),
                  ),
                ),
                if (hasPath) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Remove image',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: _uploadingDocument
                        ? null
                        : () => setState(() => _documentPathController.clear()),
                  ),
                ],
              ],
            ),
            if (fieldState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  fieldState.errorText ?? '',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _pickerField({
    required String label,
    required String? value,
    required bool loading,
    required VoidCallback onTap,
    required VoidCallback onRefresh,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            onTap: loading ? null : onTap,
            child: InputDecorator(
              decoration: _decoration(label),
              child: Text(
                value ?? (loading ? 'Loading...' : 'Tap to select'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : const Icon(Icons.refresh, color: Colors.white70),
          tooltip: 'Refresh',
        ),
      ],
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
                  onTap: () => _openStatusPicker(allowClear: true),
                  child: InputDecorator(
                    decoration: _decoration('Filter by Status'),
                    child: Text(
                      _filterStatusId == null
                          ? 'All Statuses -- tap to filter'
                          : _statusNameFor(_filterStatusId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_filterStatusId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  tooltip: 'Clear status filter',
                  onPressed: () => _onStatusFilterChanged(null),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadVerifications,
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
            controller: _searchController,
            onChanged: _filterVerifications,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID, account ID, or name on ID',
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
          child: _loadingVerifications
              ? const Center(child: CircularProgressIndicator())
              : _filteredVerifications.isEmpty
                  ? const Center(
                      child: Text(
                        'No identity verification records found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: _filteredVerifications.length,
                        itemBuilder: (context, index) {
                          final v = _filteredVerifications[index];
                          return ListTile(
                            title: Text(
                              v.fullNameOnId,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'ID: ${v.id}  •  Account #${v.accountId}  •  '
                              '${_typeNameFor(v.verificationTypeId)}  •  '
                              '${_statusNameFor(v.verificationStatusId)}',
                              style: const TextStyle(color: Colors.white54),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white70),
                                  onPressed: () => _startEdit(v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _confirmDelete(v),
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

/// Searchable account picker, mirroring _StatusPickerDialog in account_info_form.dart.
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
            a.id.toString().contains(q) ||
            a.firstName.toLowerCase().contains(q) ||
            a.lastName.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q);
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
                      child: Text('No accounts found',
                          style: TextStyle(color: Colors.white54)),
                    )
                  : ListView(
                      children: [
                        if (widget.allowClear)
                          ListTile(
                            leading: const Icon(Icons.clear, color: Colors.white70),
                            title: const Text('None',
                                style: TextStyle(color: Colors.white)),
                            onTap: () => Navigator.pop(
                              context,
                              AccountModel(
                                id: -1,
                                firstName: '',
                                lastName: '',
                                phoneNum: '',
                                email: '',
                                statusId: -1,
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

/// Searchable verification-type picker with an inline "add new" action.
class _VerificationTypePickerDialog extends StatefulWidget {
  final List<VerificationTypeModel> types;

  const _VerificationTypePickerDialog({required this.types});

  @override
  State<_VerificationTypePickerDialog> createState() =>
      _VerificationTypePickerDialogState();
}

class _VerificationTypePickerDialogState
    extends State<_VerificationTypePickerDialog> {
  final _searchController = TextEditingController();
  late List<VerificationTypeModel> _filtered;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _filtered = widget.types;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.types
          .where((t) => q.isEmpty || t.idType.toLowerCase().contains(q))
          .toList();
    });
  }

  Future<void> _createNew() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _creating = true);
    try {
      final result = await IdentityVerificationApiService.createType(q);
      final newId = result['VerificationTypeID'] as int;
      if (!mounted) return;
      Navigator.pop(context, VerificationTypeModel(id: newId, idType: q));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _creating = false);
    }
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
                  hintText: 'Search or add a new ID type',
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
                      child: Text('No verification types found',
                          style: TextStyle(color: Colors.white54)),
                    )
                  : ListView(
                      children: [
                        for (final type in _filtered)
                          ListTile(
                            title: Text(type.idType,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text('ID: ${type.id}',
                                style: const TextStyle(color: Colors.white54)),
                            onTap: () => Navigator.pop(context, type),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  if (_searchController.text.trim().isNotEmpty)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _creating ? null : _createNew,
                        icon: _creating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: Text('Add "${_searchController.text.trim()}"'),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable verification-status picker with an inline "add new" action.
class _VerificationStatusPickerDialog extends StatefulWidget {
  final List<VerificationStatusModel> statuses;
  final bool allowClear;

  const _VerificationStatusPickerDialog({
    required this.statuses,
    this.allowClear = false,
  });

  @override
  State<_VerificationStatusPickerDialog> createState() =>
      _VerificationStatusPickerDialogState();
}

class _VerificationStatusPickerDialogState
    extends State<_VerificationStatusPickerDialog> {
  final _searchController = TextEditingController();
  late List<VerificationStatusModel> _filtered;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _filtered = widget.statuses;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.statuses
          .where((s) => q.isEmpty || s.statusName.toLowerCase().contains(q))
          .toList();
    });
  }

  Future<void> _createNew() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _creating = true);
    try {
      final result = await IdentityVerificationApiService.createStatus(q);
      final newId = result['VerificationStatusID'] as int;
      if (!mounted) return;
      Navigator.pop(context, VerificationStatusModel(id: newId, statusName: q));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _creating = false);
    }
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
                  hintText: 'Search or add a new status',
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
                      child: Text('No verification statuses found',
                          style: TextStyle(color: Colors.white54)),
                    )
                  : ListView(
                      children: [
                        if (widget.allowClear)
                          ListTile(
                            leading: const Icon(Icons.clear, color: Colors.white70),
                            title: const Text('All Statuses',
                                style: TextStyle(color: Colors.white)),
                            onTap: () => Navigator.pop(
                              context,
                              VerificationStatusModel(id: -1, statusName: 'All Statuses'),
                            ),
                          ),
                        for (final status in _filtered)
                          ListTile(
                            title: Text(status.statusName,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text('ID: ${status.id}',
                                style: const TextStyle(color: Colors.white54)),
                            onTap: () => Navigator.pop(context, status),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  if (_searchController.text.trim().isNotEmpty)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _creating ? null : _createNew,
                        icon: _creating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: Text('Add "${_searchController.text.trim()}"'),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
