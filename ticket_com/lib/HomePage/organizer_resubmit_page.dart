import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ticket_com/services/event_api_service.dart' show EventOrganizer;
import 'package:ticket_com/services/event_organizer_api_service.dart'
    show EventOrganizerApiService;
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kRed = Color(0xFFE53935);

/// Shown to the owner of a DENIED organization: they can read the reviewer's
/// comment, fix the name / description / logo and press Save, which sends the
/// organization back to Pending for another review.
///
/// Pops with `true` once it has been saved and resubmitted.
class OrganizerResubmitPage extends StatefulWidget {
  const OrganizerResubmitPage({super.key, required this.organizer});

  final EventOrganizer organizer;

  @override
  State<OrganizerResubmitPage> createState() => _OrganizerResubmitPageState();
}

class _OrganizerResubmitPageState extends State<OrganizerResubmitPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.organizer.name);
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.organizer.description ?? '');
  final ImagePicker _picker = ImagePicker();

  Uint8List? _newLogoBytes;
  String _newLogoName = 'logo.jpg';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickLogo() async {
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
    if (source == null) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newLogoBytes = bytes;
        _newLogoName = picked.name.trim().isNotEmpty ? picked.name : 'logo.jpg';
      });
    } catch (e) {
      _snack('Could not open camera/gallery: $e');
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await EventOrganizerApiService.resubmitOrganizer(
        id: widget.organizer.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        bytes: _newLogoBytes,
        filename: _newLogoName,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Save failed: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Widget _logoPreview() {
    final existing = widget.organizer.logoPath;
    Widget fallback() => Container(
          color: kAccent.withValues(alpha: 0.12),
          child: const Icon(Icons.apartment, color: kAccent, size: 36),
        );
    Widget image;
    if (_newLogoBytes != null) {
      image = Image.memory(_newLogoBytes!, fit: BoxFit.cover);
    } else if (existing != null && existing.isNotEmpty) {
      image = Image.network(
        EventOrganizerApiService.fullImageUrl(existing),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    } else {
      image = fallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(width: 84, height: 84, child: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.organizer.denyReason?.trim() ?? '';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: const Text(
          'Edit organization',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kRed.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.feedback_outlined, color: _kRed, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Reviewer comment',
                          style: TextStyle(
                            color: _kRed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reason.isNotEmpty ? reason : 'No comment was left.',
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fix this, then press Save to send your organization '
                      'for review again.',
                      style: TextStyle(color: _kTextGrey, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _logoPreview(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickLogo,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _newLogoBytes == null ? 'Change logo' : 'Pick another',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Organization name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_saving,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: kAccent),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
