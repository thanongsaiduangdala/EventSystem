import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/identity_verification_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

const int _kPending = 1;
const int _kApproved = 2;
const int _kDenied = 3;

/// Self-service identity verification form shown to a user who was invited to
/// join an organization team but has not been verified yet. Kept deliberately
/// separate from [BecomeOrganizerPage] so the invite flow never also creates
/// an organizer profile -- only identity verification happens here.
class IdentityVerificationSubmitPage extends StatefulWidget {
  const IdentityVerificationSubmitPage({super.key});

  @override
  State<IdentityVerificationSubmitPage> createState() =>
      _IdentityVerificationSubmitPageState();
}

class _IdentityVerificationSubmitPageState
    extends State<IdentityVerificationSubmitPage> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _fullNameController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  bool _loading = true;
  bool _submitting = false;
  bool _uploadingDocument = false;
  String? _error;

  List<VerificationTypeModel> _types = [];
  IdentityVerificationModel? _latest;

  int? _selectedTypeId;
  DateTime? _dateOfBirth;
  String? _documentPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  UserSession? get _session => AuthService.currentSession;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = _session;
      if (session == null) {
        throw Exception('You must be logged in');
      }
      final types = await IdentityVerificationApiService.getAllTypes();
      final verifications = await IdentityVerificationApiService
          .getVerificationsByAccount(session.accountId);
      if (!mounted) return;
      setState(() {
        _types = types;
        if (_selectedTypeId == null && types.isNotEmpty) {
          _selectedTypeId = types.first.id;
        }
        _latest = verifications.isEmpty
            ? null
            : (verifications
                ..sort((a, b) => b.id.compareTo(a.id)))
                .first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _verified => _latest?.verificationStatusId == _kApproved;

  bool get _pending => _latest?.verificationStatusId == _kPending;

  Future<void> _chooseDocumentImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: _kTextDark),
              title: const Text('Take Photo',
                  style: TextStyle(color: _kTextDark)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _kTextDark),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: _kTextDark)),
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
      final filename =
          picked.name.trim().isNotEmpty ? picked.name : 'document.jpg';
      final path = await IdentityVerificationApiService.uploadDocumentImage(
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) return;
      setState(() => _documentPath = path);
      _snack('Document image uploaded');
    } catch (e) {
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingDocument = false);
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
      setState(() => _dateOfBirth = picked);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateOfBirth == null) {
      _snack('Please select your date of birth');
      return;
    }
    if (_documentPath == null || _documentPath!.isEmpty) {
      _snack('Please upload your ID document photo');
      return;
    }
    final session = _session;
    if (session == null) return;

    setState(() => _submitting = true);
    try {
      await IdentityVerificationApiService.createVerification(
        accountId: session.accountId,
        verificationTypeId: _selectedTypeId ?? 1,
        idNumberEncrypted: _idNumberController.text.trim(),
        fullNameOnId: _fullNameController.text.trim(),
        dateOfBirth: _fmtDate(_dateOfBirth!),
        documentImagePath: _documentPath!,
        verificationStatusId: _kPending,
        submittedAtYmdt: _fmtDateTime(DateTime.now()),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _load();
      if (!mounted) return;
      _snack('Identity verification submitted. An admin will review it.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('Submission failed: $e');
    }
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: const Text(
          'Identity Verification',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kAccent),
            )
          : _error != null
              ? _errorBox()
              : _session == null
                  ? _loginBox()
                  : _verified
                      ? _statusView(
                          icon: Icons.verified_user,
                          color: const Color(0xFF2E9E5B),
                          title: 'Identity Verified',
                          message:
                              'Your identity has already been verified. You can '
                              'now decide whether to join the organization.',
                        )
                      : _pending
                          ? _statusView(
                              icon: Icons.hourglass_top,
                              color: kAccent,
                              title: 'Verification Pending',
                              message:
                                  'Your identity verification has been submitted '
                                  'and is waiting for admin review. Please come '
                                  'back once it has been approved.',
                            )
                          : _formView(),
    );
  }

  Widget _formView() {
    final denied = _latest?.verificationStatusId == _kDenied;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kAccent, Color(0xFF8E2DE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.badge_outlined, color: Colors.white, size: 34),
              const SizedBox(height: 12),
              const Text(
                'Verify your identity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                denied
                    ? 'Your previous application was not approved. Please submit '
                        'a new application with the correct information.'
                    : 'Fill in your identity details and upload a photo of your ID. '
                        'An admin will review and approve it, then you can continue '
                        'joining the organization.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _formCard(),
      ],
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fieldLabel('ID type'),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _selectedTypeId,
              decoration: _decoration(hint: 'Select ID type'),
              items: _types
                  .map((t) => DropdownMenuItem<int>(
                        value: t.id,
                        child: Text(t.idType,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedTypeId = v),
              validator: (v) => v == null ? 'Select your ID type' : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('ID number'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _idNumberController,
              decoration: _decoration(hint: 'Enter your ID number'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter your ID number'
                  : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Full name on ID'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _fullNameController,
              decoration: _decoration(hint: 'Name as shown on your ID'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter the full name on your ID'
                  : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Date of birth'),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDateOfBirth,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                height: 52,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x33000000)),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFFAFAFA),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined,
                        color: _dateOfBirth == null ? _kTextGrey : kAccent),
                    const SizedBox(width: 10),
                    Text(
                      _dateOfBirth == null
                          ? 'Select your date of birth'
                          : _fmtDate(_dateOfBirth!),
                      style: TextStyle(
                        color: _dateOfBirth == null ? _kTextGrey : _kTextDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _fieldLabel('ID document photo'),
            const SizedBox(height: 6),
            _uploadTile(),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Submit Verification',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadTile() {
    final previewPath = _documentPath;
    return InkWell(
      onTap: _uploadingDocument ? null : _chooseDocumentImageSource,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x33000000)),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFAFAFA),
        ),
        child: _uploadingDocument
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: kAccent, strokeWidth: 2.5),
                ),
              )
            : previewPath == null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_a_photo_outlined, color: _kTextGrey),
                      SizedBox(width: 8),
                      Text(
                        'Upload photo of ID / passport',
                        style: TextStyle(color: _kTextGrey),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _previewUrl(previewPath),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Document uploaded — tap to replace',
                          style: TextStyle(color: _kTextGrey, fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.check_circle,
                          color: Color(0xFF2E9E5B)),
                      const SizedBox(width: 12),
                    ],
                  ),
      ),
    );
  }

  String _previewUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${IdentityVerificationApiService.baseUrl}/static/$path';
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _kTextDark,
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  InputDecoration _decoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kTextGrey, fontSize: 13.5),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x33000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.6),
      ),
    );
  }

  Widget _statusView({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextGrey,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                style: OutlinedButton.styleFrom(foregroundColor: kAccent),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorBox() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: _kTextGrey, size: 40),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextGrey),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: kAccent),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginBox() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: _kTextGrey, size: 40),
            const SizedBox(height: 10),
            const Text(
              'Please log in to verify your identity.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextGrey),
            ),
          ],
        ),
      ),
    );
  }
}