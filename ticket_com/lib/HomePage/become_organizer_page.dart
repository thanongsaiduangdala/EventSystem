import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_organizer_api_service.dart';
import 'package:ticket_com/services/identity_verification_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

const int _kPending = 1;
const int _kApproved = 2;
const int _kDenied = 3;

class BecomeOrganizerPage extends StatefulWidget {
  const BecomeOrganizerPage({super.key});

  @override
  State<BecomeOrganizerPage> createState() => _BecomeOrganizerPageState();
}

class _BecomeOrganizerPageState extends State<BecomeOrganizerPage> {
  final _formKey = GlobalKey<FormState>();
  final _orgFormKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _orgDescriptionController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  bool _loading = true;
  String? _error;

  bool _hasOrganizerProfile = false;

  List<VerificationTypeModel> _types = [];
  List<IdentityVerificationModel> _verifications = [];

  int? _selectedTypeId;
  DateTime? _dateOfBirth;
  String? _documentPath;

  Uint8List? _orgLogoBytes;
  String _orgLogoName = 'logo.jpg';
  bool _uploadingLogo = false;
  bool _creatingProfile = false;

  bool _uploadingDocument = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _fullNameController.dispose();
    _orgNameController.dispose();
    _orgDescriptionController.dispose();
    super.dispose();
  }

  UserSession? get _session => AuthService.currentSession;

  IdentityVerificationModel? get _latestVerification {
    if (_verifications.isEmpty) return null;
    final sorted = [..._verifications]
      ..sort((a, b) => b.id.compareTo(a.id));
    return sorted.first;
  }

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
      final myOrganizers = await EventOrganizerApiService.getAllOrganizers();
      if (!mounted) return;
      setState(() {
        _types = types;
        if (_selectedTypeId == null && types.isNotEmpty) {
          _selectedTypeId = types.first.id;
        }
        _verifications = verifications;
        _hasOrganizerProfile = myOrganizers
            .any((o) => o.createdByAccountId == session.accountId);
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

  // ---------------- document image ----------------

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

  // ---------------- organizer logo ----------------

  Future<void> _chooseLogoImage() async {
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
      await _pickLogoImage(source);
    }
  }

  Future<void> _pickLogoImage(ImageSource source) async {
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
    final file = picked;

    setState(() => _uploadingLogo = true);
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _orgLogoBytes = bytes;
      _orgLogoName =
          file.name.trim().isNotEmpty ? file.name : 'logo.jpg';
      _uploadingLogo = false;
    });
  }

  // ---------------- submit ----------------

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
    if (_orgLogoBytes == null) {
      _snack('Please upload your organization logo');
      return;
    }
    final session = _session;
    if (session == null) return;

    setState(() => _isSubmitting = true);
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
      String orgNote = '';
      if (!_hasOrganizerProfile) {
        try {
          await EventOrganizerApiService.applyOrganizer(
            bytes: _orgLogoBytes!,
            filename: _orgLogoName,
            name: _orgNameController.text.trim(),
            createdByAccountId: session.accountId,
            description: _orgDescriptionController.text.trim().isEmpty
                ? null
                : _orgDescriptionController.text.trim(),
          );
        } catch (orgError) {
          orgNote = ' Your organization profile could not be created yet.';
        }
      }
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await _load();
      if (!mounted) return;
      _snack('Application submitted. Our team will review it shortly.$orgNote');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _snack('Submission failed: $e');
    }
  }

  Future<void> _createOrganizerProfile() async {
    if (!(_orgFormKey.currentState?.validate() ?? false)) return;
    if (_orgLogoBytes == null) {
      _snack('Please upload your organization logo');
      return;
    }
    final session = _session;
    if (session == null) return;

    setState(() => _creatingProfile = true);
    try {
      await EventOrganizerApiService.uploadOrganizer(
        bytes: _orgLogoBytes!,
        filename: _orgLogoName,
        name: _orgNameController.text.trim(),
        createdByAccountId: session.accountId,
        description: _orgDescriptionController.text.trim().isEmpty
            ? null
            : _orgDescriptionController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _creatingProfile = false);
      await _load();
      if (!mounted) return;
      _snack('Your organizer profile has been created!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _creatingProfile = false);
      _snack('Profile creation failed: $e');
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

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: const Text(
          'Become an Organizer',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kAccent),
            )
          : _error != null
              ? _errorBox()
              : session == null
                  ? _loginBox()
                  : session.isOrganizer || session.isSuperAdmin
                      ? _hasOrganizerProfile
                          ? _statusView(
                              icon: Icons.storefront,
                              color: const Color(0xFF2E9E5B),
                              title: 'You already have organizer access',
                              message:
                                  'As a ${session.isSuperAdmin ? 'SUPERADMIN' : 'verified organizer'} '
                                  'you can create and manage events from the app.',
                            )
                          : _noProfileView()
                      : _latestVerification == null
                          ? _deniedLast
                              ? _deniedView()
                              : _formView()
                          : _verificationView(),
    );
  }

  Widget _verificationView() {
    final latest = _latestVerification!;
    switch (latest.verificationStatusId) {
      case _kApproved:
        return _statusView(
          icon: Icons.verified_user,
          color: const Color(0xFF2E9E5B),
          title: 'Application Approved',
          message:
              'Your identity has been verified. Please log out and log back '
              'in to access the Organizers Dashboard and create events from '
              'the app.',
        );
      case _kDenied:
        return _deniedView();
      case _kPending:
      default:
        return _statusView(
          icon: Icons.hourglass_top,
          color: kAccent,
          title: 'Application Pending',
          message: 'You\'re almost there! Your application has been submitted '
              'and is waiting for admin/employee review.',
        );
    }
  }

  bool get _deniedLast =>
      _latestVerification?.verificationStatusId == _kDenied;

  Widget _deniedView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _statusView(
          icon: Icons.gpp_bad,
          color: const Color(0xFFE53935),
          title: 'Application Denied',
          message:
              'Your previous application was not approved. Please review the '
              'details below and submit a new application with correct '
              'information.',
        ),
        const SizedBox(height: 16),
        _formView(sign: true),
      ],
    );
  }

  Widget _formView({bool sign = false}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _headerCard(),
        const SizedBox(height: 16),
        _formCard(),
      ],
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kAccent, Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storefront_outlined, color: Colors.white, size: 34),
          const SizedBox(height: 12),
          const Text(
            'Start organizing events',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Fill in your identity details and upload a photo of your ID. '
            'Our team will review and approve your organizer account.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noProfileView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Icon(Icons.storefront_outlined, color: _kTextGrey, size: 48),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'No organizer profile yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kTextDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Your organizer account has organizer access, but no organizer '
            'profile is linked to your account yet. Answer the questions below '
            'to set up your organization profile.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kTextGrey, fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 20),
        _organizationCard(),
      ],
    );
  }

  Widget _organizationCard() {
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
        key: _orgFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.store, color: kAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Organization details',
                  style: TextStyle(
                    color: _kTextDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tell us about the organization you want to use to organize events.',
              style: TextStyle(color: _kTextGrey, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            _fieldLabel('What is your organization name?'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _orgNameController,
              decoration: _decoration(
                hint: 'e.g. Vientiane Music Festival Co.',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter your organization name'
                  : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Organization logo'),
            const SizedBox(height: 6),
            _logoUploadTile(),
            const SizedBox(height: 16),
            _fieldLabel('Tell us about your organization (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _orgDescriptionController,
              maxLines: 3,
              decoration: _decoration(
                hint: 'What kind of events does your organization run?',
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _creatingProfile ? null : _createOrganizerProfile,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _creatingProfile
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Create Organizer Profile',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoUploadTile() {
    return InkWell(
      onTap: _uploadingLogo ? null : _chooseLogoImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x33000000)),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFAFAFA),
        ),
        child: _uploadingLogo
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: kAccent, strokeWidth: 2.5),
                ),
              )
            : _orgLogoBytes == null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.image_outlined, color: _kTextGrey),
                      SizedBox(width: 8),
                      Text(
                        'Upload organization logo',
                        style: TextStyle(color: _kTextGrey),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _orgLogoBytes!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Logo selected — tap to replace',
                          style: TextStyle(color: _kTextGrey, fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.check_circle, color: Color(0xFF2E9E5B)),
                      const SizedBox(width: 12),
                    ],
                  ),
      ),
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
                        child: Text(t.idType, maxLines: 1,
                            overflow: TextOverflow.ellipsis),
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
                        color: _dateOfBirth == null
                            ? _kTextGrey
                            : kAccent),
                    const SizedBox(width: 10),
                    Text(
                      _dateOfBirth == null
                          ? 'Select your date of birth'
                          : _fmtDate(_dateOfBirth!),
                      style: TextStyle(
                        color: _dateOfBirth == null
                            ? _kTextGrey
                            : _kTextDark,
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
            const SizedBox(height: 26),
            const Divider(color: Color(0x1F000000), height: 1),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.store, color: kAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Organization details',
                  style: TextStyle(
                    color: _kTextDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Fill in the details of the organization you will use to organize '
              'events. This will create your organizer profile.',
              style: TextStyle(color: _kTextGrey, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            _fieldLabel('What is your organization name?'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _orgNameController,
              decoration: _decoration(
                hint: 'e.g. Vientiane Music Festival Co.',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter your organization name'
                  : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Organization logo'),
            const SizedBox(height: 6),
            _logoUploadTile(),
            const SizedBox(height: 16),
            _fieldLabel('Tell us about your organization (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _orgDescriptionController,
              maxLines: 3,
              decoration: _decoration(
                hint: 'What kind of events does your organization run?',
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Submit Application',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadTile() {
    final previewUrl =
        _documentPath == null ? '' : _documentPreviewUrl(_documentPath!);
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
            : _documentPath == null
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
                          previewUrl,
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
                      const Icon(Icons.check_circle, color: Color(0xFF2E9E5B)),
                      const SizedBox(width: 12),
                    ],
                  ),
      ),
    );
  }

  String _documentPreviewUrl(String path) {
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
              'Please log in to apply as an organizer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextGrey),
            ),
          ],
        ),
      ),
    );
  }
}