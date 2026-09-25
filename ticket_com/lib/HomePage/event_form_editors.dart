import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:ticket_com/DeveloperPage/SearchDialog/icon_picker_dialog.dart';
import 'package:ticket_com/DeveloperPage/square_crop_page.dart';
import 'package:ticket_com/models/category_models.dart';
import 'package:ticket_com/models/sponser_models.dart';
import 'package:ticket_com/services/category_api_service.dart';
import 'package:ticket_com/services/event_question_api_service.dart';
import 'package:ticket_com/services/sponser_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';
import 'package:ticket_com/utils/category_icons.dart';

const Color _kLavender = Color(0xFFEFEEFC);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kBorder = Color(0xFFE9E8F8);
const Color _kRed = Color(0xFFE53935);

/// EventQuestionTypeID values that need >= 2 options (Checkbox, Radio box).
/// Must match the question types in the database.
const Set<int> kOptionQuestionTypeIds = {2, 3};

// ---------------------------------------------------------------------------
// helpers shared with event_form_page.dart
// ---------------------------------------------------------------------------

String _two(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)}  '
    '${_two(dt.hour)}:${_two(dt.minute)}';

String formatDateTimeForApi(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
    '${_two(dt.hour)}:${_two(dt.minute)}:00';

String formatKip(int value) {
  if (value <= 0) return 'Free';
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$buf KIP';
}

/// Turns an exception (or a raw JSON error body) into a short readable line.
String friendlyError(Object e) {
  var msg = e.toString();
  if (msg.startsWith('Exception: ')) msg = msg.substring(11);
  final trimmed = msg.trim();
  if (trimmed.startsWith('{')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // keep the raw message
    }
  }
  return msg;
}

/// The backend only accepts .jpg/.jpeg/.png/.webp/.gif and decides by file
/// extension, but picked files (especially on web) don't always carry a
/// usable name. Sniff the real format from the first bytes instead.
String imageExtensionFor(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8) return 'jpg';
  if (b.length >= 4 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47) {
    return 'png';
  }
  if (b.length >= 4 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
    return 'gif';
  }
  if (b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return 'webp';
  }
  return 'jpg';
}

Future<DateTime?> pickDateTime(
  BuildContext context,
  DateTime? initial, {
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final now = DateTime.now();
  final first = firstDate ?? DateTime(now.year - 2);
  final last = lastDate ?? DateTime(now.year + 5);
  var start = initial ?? now;
  if (start.isBefore(first)) start = first;
  if (start.isAfter(last)) start = last;

  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: first,
    lastDate: last,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: initial != null
        ? TimeOfDay.fromDateTime(initial)
        : TimeOfDay.now(),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

InputDecoration _fieldDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: _kTextGrey, fontSize: 13.5),
    hintStyle: const TextStyle(color: _kTextGrey, fontSize: 13.5),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    isDense: true,
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
      borderSide: const BorderSide(color: _kRed),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kRed, width: 1.6),
    ),
  );
}

Widget _sheetHandle() => Center(
  child: Container(
    width: 42,
    height: 4,
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: const Color(0x22000000),
      borderRadius: BorderRadius.circular(4),
    ),
  ),
);

Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => child,
  );
}

// ---------------------------------------------------------------------------
// drafts (what the form edits before anything is sent to the server)
// ---------------------------------------------------------------------------

/// A photo on the form: either one that already exists on the server
/// ([id] + [path]) or one just picked from the gallery ([bytes]).
class EventImageDraft {
  EventImageDraft({
    this.id,
    this.path,
    this.bytes,
    this.filename,
    this.isCover = false,
  });

  int? id;
  String? path;
  Uint8List? bytes;
  String? filename;
  bool isCover;
}

class TicketTypeDraft {
  TicketTypeDraft({
    this.id,
    required this.name,
    required this.price,
    required this.capacity,
    required this.saleStart,
    required this.saleEnd,
    this.dirty = false,
  });

  factory TicketTypeDraft.fromModel(TicketTypeModel m) {
    return TicketTypeDraft(
      id: m.id,
      name: m.typeName,
      price: m.priceInKip,
      capacity: m.capacity,
      saleStart: DateTime.tryParse(m.saleStart) ?? DateTime.now(),
      saleEnd: DateTime.tryParse(m.saleEnd) ?? DateTime.now(),
    );
  }

  /// Server id; null until the ticket type has been created.
  int? id;
  String name;
  int price;
  int capacity;
  DateTime saleStart;
  DateTime saleEnd;

  /// True when an existing ticket type was edited and needs an update call.
  bool dirty;
}

class QuestionDraft {
  QuestionDraft({
    this.id,
    required this.text,
    required this.typeId,
    this.isRequired = true,
    List<String>? options,
    this.serverSort,
    this.dirty = false,
  }) : options = options ?? <String>[];

  factory QuestionDraft.fromModel(EventQuestionModel m) {
    return QuestionDraft(
      id: m.id,
      text: m.question,
      typeId: m.questionTypeId,
      isRequired: m.isRequire,
      options: m.options == null ? <String>[] : List<String>.from(m.options!),
      serverSort: m.sortOrder,
    );
  }

  int? id;
  String text;
  int typeId;
  bool isRequired;
  List<String> options;

  /// SortOrder currently stored on the server (null for unsaved questions).
  int? serverSort;
  bool dirty;
}

// ---------------------------------------------------------------------------
// ticket type editor
// ---------------------------------------------------------------------------

Future<TicketTypeDraft?> showTicketTypeSheet(
  BuildContext context, {
  TicketTypeDraft? initial,
  DateTime? eventStart,
}) {
  return _showSheet<TicketTypeDraft>(
    context,
    _TicketTypeSheet(initial: initial, eventStart: eventStart),
  );
}

class _TicketTypeSheet extends StatefulWidget {
  const _TicketTypeSheet({this.initial, this.eventStart});

  final TicketTypeDraft? initial;
  final DateTime? eventStart;

  @override
  State<_TicketTypeSheet> createState() => _TicketTypeSheetState();
}

class _TicketTypeSheetState extends State<_TicketTypeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  DateTime? _saleStart;
  DateTime? _saleEnd;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _nameController.text = t.name;
      _priceController.text = t.price.toString();
      _capacityController.text = t.capacity.toString();
      _saleStart = t.saleStart;
      _saleEnd = t.saleEnd;
    } else {
      final now = DateTime.now();
      _saleStart = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      final eventStart = widget.eventStart;
      if (eventStart != null && eventStart.isAfter(_saleStart!)) {
        _saleEnd = eventStart;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await pickDateTime(context, _saleStart);
    if (picked != null && mounted) {
      setState(() {
        _saleStart = picked;
        _dateError = null;
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await pickDateTime(context, _saleEnd ?? _saleStart);
    if (picked != null && mounted) {
      setState(() {
        _saleEnd = picked;
        _dateError = null;
      });
    }
  }

  void _submit() {
    final formOk = _formKey.currentState?.validate() ?? false;
    String? dateError;
    if (_saleStart == null || _saleEnd == null) {
      dateError = 'Choose when ticket sales open and close';
    } else if (!_saleEnd!.isAfter(_saleStart!)) {
      dateError = 'Sales must close after they open';
    }
    setState(() => _dateError = dateError);
    if (!formOk || dateError != null) return;

    Navigator.pop(
      context,
      TicketTypeDraft(
        id: widget.initial?.id,
        name: _nameController.text.trim(),
        price: int.parse(_priceController.text.trim()),
        capacity: int.parse(_capacityController.text.trim()),
        saleStart: _saleStart!,
        saleEnd: _saleEnd!,
        dirty: true,
      ),
    );
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33000000)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, color: kAccent, size: 18),
            const SizedBox(width: 10),
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
              ),
            ),
            Expanded(
              child: Text(
                value == null ? 'Select date & time' : formatDateTime(value),
                style: TextStyle(
                  color: value == null ? _kTextGrey : _kTextDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHandle(),
              Text(
                isEdit ? 'Edit ticket type' : 'Add ticket type',
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'For example "Regular", "VIP" or "Early bird".',
                style: TextStyle(color: _kTextGrey, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                maxLength: 45,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration('Ticket name').copyWith(
                  counterText: '',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter a ticket name'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: _fieldDecoration(
                        'Price (KIP)',
                        hint: '0 = free',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a price'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(7),
                      ],
                      decoration: _fieldDecoration('Capacity'),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n < 1) return 'At least 1';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _dateTile('Sales open', _saleStart, _pickStart),
              const SizedBox(height: 10),
              _dateTile('Sales close', _saleEnd, _pickEnd),
              if (_dateError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _dateError!,
                  style: const TextStyle(color: _kRed, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEdit ? 'Update ticket type' : 'Add ticket type',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// question editor
// ---------------------------------------------------------------------------

Future<QuestionDraft?> showQuestionSheet(
  BuildContext context, {
  required List<EventQuestionTypeModel> types,
  QuestionDraft? initial,
}) {
  return _showSheet<QuestionDraft>(
    context,
    _QuestionSheet(types: types, initial: initial),
  );
}

class _QuestionSheet extends StatefulWidget {
  const _QuestionSheet({required this.types, this.initial});

  final List<EventQuestionTypeModel> types;
  final QuestionDraft? initial;

  @override
  State<_QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<_QuestionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  int? _typeId;
  bool _isRequired = true;
  String? _optionsError;

  bool get _needsOptions =>
      _typeId != null && kOptionQuestionTypeIds.contains(_typeId);

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    if (q != null) {
      _questionController.text = q.text;
      _typeId = q.typeId;
      _isRequired = q.isRequired;
      for (final o in q.options) {
        _optionControllers.add(TextEditingController(text: o));
      }
    } else if (widget.types.isNotEmpty) {
      _typeId = widget.types.first.id;
    }
    // The dropdown asserts if its value isn't one of the items.
    if (widget.types.isNotEmpty &&
        !widget.types.any((t) => t.id == _typeId)) {
      _typeId = widget.types.first.id;
    }
    while (_optionControllers.length < 2) {
      _optionControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _submit() {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (_typeId == null) return;

    final options = <String>[];
    String? optionsError;
    if (_needsOptions) {
      for (final c in _optionControllers) {
        final v = c.text.trim();
        if (v.isNotEmpty && !options.contains(v)) options.add(v);
      }
      if (options.length < 2) {
        optionsError = 'Add at least 2 different answer options';
      }
    }
    setState(() => _optionsError = optionsError);
    if (!formOk || optionsError != null) return;

    Navigator.pop(
      context,
      QuestionDraft(
        id: widget.initial?.id,
        text: _questionController.text.trim(),
        typeId: _typeId!,
        isRequired: _isRequired,
        options: _needsOptions ? options : <String>[],
        serverSort: widget.initial?.serverSort,
        dirty: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final noTypes = widget.types.isEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHandle(),
              Text(
                isEdit ? 'Edit question' : 'Add question',
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Attendees answer this when they buy a ticket.',
                style: TextStyle(color: _kTextGrey, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _questionController,
                maxLength: 255,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration('Question').copyWith(
                  counterText: '',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter the question'
                    : null,
              ),
              const SizedBox(height: 12),
              if (noTypes)
                const Text(
                  "Question types couldn't be loaded, so questions can't be "
                  'added right now. Close this and try again.',
                  style: TextStyle(color: _kRed, fontSize: 12.5),
                )
              else
                DropdownButtonFormField<int>(
                  initialValue: _typeId,
                  isExpanded: true,
                  decoration: _fieldDecoration('Answer type'),
                  items: [
                    for (final t in widget.types)
                      DropdownMenuItem<int>(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _typeId = v;
                    _optionsError = null;
                  }),
                ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isRequired,
                onChanged: (v) => setState(() => _isRequired = v),
                activeThumbColor: kAccent,
                title: const Text(
                  'Required',
                  style: TextStyle(
                    color: _kTextDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Attendees must answer before they can buy',
                  style: TextStyle(color: _kTextGrey, fontSize: 12),
                ),
              ),
              if (_needsOptions) ...[
                const SizedBox(height: 8),
                const Text(
                  'Answer options',
                  style: TextStyle(
                    color: _kTextDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _optionControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _optionControllers[i],
                            maxLength: 100,
                            decoration: _fieldDecoration(
                              'Option ${i + 1}',
                            ).copyWith(counterText: ''),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove option',
                          onPressed: _optionControllers.length > 2
                              ? () => _removeOption(i)
                              : null,
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addOption,
                    style: TextButton.styleFrom(foregroundColor: kAccent),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add option',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (_optionsError != null)
                  Text(
                    _optionsError!,
                    style: const TextStyle(color: _kRed, fontSize: 12),
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: noTypes ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEdit ? 'Update question' : 'Add question',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// sponsors: picker + "new sponsor" sheet
// ---------------------------------------------------------------------------

class SponsorPickResult {
  SponsorPickResult({required this.selected, required this.sponsors});

  final Set<int> selected;

  /// Full sponsor list, including any sponsor created inside the sheet.
  final List<SponserModel> sponsors;
}

Future<SponsorPickResult?> showSponsorPickerSheet(
  BuildContext context, {
  required List<SponserModel> sponsors,
  required Set<int> selected,
}) {
  return _showSheet<SponsorPickResult>(
    context,
    _SponsorPickerSheet(sponsors: sponsors, selected: selected),
  );
}

/// Sponsor logo, or the sponsor's initial when there is no usable image.
class SponsorLogo extends StatelessWidget {
  const SponsorLogo({super.key, required this.sponsor, this.size = 40});

  final SponserModel sponsor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = sponsor.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: _kLavender,
      child: Text(
        initial,
        style: TextStyle(
          color: kAccent,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (sponsor.logoPath.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.network(
        SponserApiService.fullImageUrl(sponsor.logoPath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _SponsorPickerSheet extends StatefulWidget {
  const _SponsorPickerSheet({required this.sponsors, required this.selected});

  final List<SponserModel> sponsors;
  final Set<int> selected;

  @override
  State<_SponsorPickerSheet> createState() => _SponsorPickerSheetState();
}

class _SponsorPickerSheetState extends State<_SponsorPickerSheet> {
  late final List<SponserModel> _sponsors = List<SponserModel>.of(
    widget.sponsors,
  );
  late final Set<int> _selected = Set<int>.of(widget.selected);
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SponserModel> get _filtered {
    if (_query.isEmpty) return _sponsors;
    return _sponsors
        .where((s) => s.name.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _createSponsor({String? initialName}) async {
    final created = await _showSheet<SponserModel>(
      context,
      _NewSponsorSheet(initialName: initialName),
    );
    if (created == null || !mounted) return;
    setState(() {
      _sponsors.add(created);
      _selected.add(created.id);
      _searchController.clear();
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHandle(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choose sponsors',
                    style: TextStyle(
                      color: _kTextDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _createSponsor(),
                  style: TextButton.styleFrom(foregroundColor: kAccent),
                  icon: const Icon(Icons.add_business_outlined, size: 18),
                  label: const Text(
                    'New sponsor',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
              style: const TextStyle(color: _kTextDark),
              decoration: _fieldDecoration('Search sponsors').copyWith(
                prefixIcon: const Icon(
                  Icons.search,
                  color: _kTextGrey,
                  size: 20,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: _kTextGrey,
                          size: 18,
                        ),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _sponsors.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'No sponsors yet. Tap "New sponsor" to add the '
                          'first one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _kTextGrey, fontSize: 13.5),
                        ),
                      ),
                    )
                  : results.isEmpty
                  ? _noMatchPrompt(
                      label: _searchController.text.trim(),
                      onCreate: () =>
                          _createSponsor(initialName: _searchController.text.trim()),
                      itemNoun: 'sponsor',
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final s = results[index];
                        final checked = _selected.contains(s.id);
                        return CheckboxListTile(
                          value: checked,
                          contentPadding: EdgeInsets.zero,
                          activeColor: kAccent,
                          controlAffinity: ListTileControlAffinity.trailing,
                          secondary: SponsorLogo(sponsor: s, size: 42),
                          title: Text(
                            s.name,
                            style: const TextStyle(
                              color: _kTextDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(s.id);
                            } else {
                              _selected.remove(s.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                SponsorPickResult(selected: _selected, sponsors: _sponsors),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _selected.isEmpty
                    ? 'Done'
                    : 'Done  (${_selected.length} selected)',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown inside a picker sheet when a search doesn't match anything --
/// lets the organizer create a new record seeded with the search text
/// instead of dead-ending on "no results".
Widget _noMatchPrompt({
  required String label,
  required VoidCallback onCreate,
  required String itemNoun,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, color: _kTextGrey, size: 30),
          const SizedBox(height: 10),
          Text(
            label.isEmpty
                ? 'No $itemNoun matches that search.'
                : 'No $itemNoun named "$label".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCreate,
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccent,
              side: const BorderSide(color: kAccent),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              label.isEmpty ? 'Add new $itemNoun' : 'Add "$label" as new $itemNoun',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NewSponsorSheet extends StatefulWidget {
  const _NewSponsorSheet({this.initialName});

  final String? initialName;

  @override
  State<_NewSponsorSheet> createState() => _NewSponsorSheetState();
}

class _NewSponsorSheetState extends State<_NewSponsorSheet> {
  late final _nameController = TextEditingController(text: widget.initialName);
  final _picker = ImagePicker();
  Uint8List? _logoBytes;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      var bytes = await picked.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null && decoded.width != decoded.height) {
        // Logos are shown as squares, same as the developer sponsor form.
        if (!mounted) return;
        final cropped = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(builder: (_) => SquareCropPage(bytes: bytes)),
        );
        if (cropped == null) return;
        bytes = cropped;
      }
      if (!mounted) return;
      setState(() {
        _logoBytes = bytes;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't open that image: ${friendlyError(e)}");
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter the sponsor name');
      return;
    }
    if (_logoBytes == null) {
      setState(() => _error = 'Choose a logo for the sponsor');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bytes = _logoBytes!;
      final result = await SponserApiService.uploadSponser(
        bytes: bytes,
        filename: 'logo.${imageExtensionFor(bytes)}',
        name: name,
      );
      final id = (result['Sponser_ID'] as num).toInt();
      final path = result['SponserLogoPath']?.toString() ?? '';
      if (!mounted) return;
      Navigator.pop(context, SponserModel(id: id, name: name, logoPath: path));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save the sponsor: ${friendlyError(e)}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHandle(),
            const Text(
              'New sponsor',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _pickLogo,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: _kLavender,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _kBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _logoBytes == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: kAccent,
                              size: 28,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Logo',
                              style: TextStyle(
                                color: kAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Image.memory(_logoBytes!, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration('Sponsor name').copyWith(
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: _kRed, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Save sponsor',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// categories: picker + "new category" sheet
// ---------------------------------------------------------------------------

class CategoryPickResult {
  CategoryPickResult({required this.selected, required this.categories});

  final Set<int> selected;

  /// Full category list, including any category created inside the sheet.
  final List<CategoryModel> categories;
}

Future<CategoryPickResult?> showCategoryPickerSheet(
  BuildContext context, {
  required List<CategoryModel> categories,
  required Set<int> selected,
}) {
  return _showSheet<CategoryPickResult>(
    context,
    _CategoryPickerSheet(categories: categories, selected: selected),
  );
}

/// Category icon in a colored circle, or a generic tag icon when the
/// category has no icon set yet.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category, this.size = 40});

  final CategoryModel category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = categoryColorFor(category.name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        category.iconPath == null || category.iconPath!.isEmpty
            ? Icons.category_outlined
            : iconForKey(category.iconPath!),
        color: color,
        size: size * 0.52,
      ),
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({required this.categories, required this.selected});

  final List<CategoryModel> categories;
  final Set<int> selected;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late final List<CategoryModel> _categories = List<CategoryModel>.of(
    widget.categories,
  );
  late final Set<int> _selected = Set<int>.of(widget.selected);
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CategoryModel> get _filtered {
    if (_query.isEmpty) return _categories;
    return _categories
        .where((c) => c.name.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _createCategory({String? initialName}) async {
    final created = await _showSheet<CategoryModel>(
      context,
      _NewCategorySheet(initialName: initialName),
    );
    if (created == null || !mounted) return;
    setState(() {
      _categories.add(created);
      _selected.add(created.id);
      _searchController.clear();
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHandle(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choose categories',
                    style: TextStyle(
                      color: _kTextDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _createCategory(),
                  style: TextButton.styleFrom(foregroundColor: kAccent),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text(
                    'New category',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
              style: const TextStyle(color: _kTextDark),
              decoration: _fieldDecoration('Search categories').copyWith(
                prefixIcon: const Icon(
                  Icons.search,
                  color: _kTextGrey,
                  size: 20,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: _kTextGrey,
                          size: 18,
                        ),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _categories.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'No categories yet. Tap "New category" to add the '
                          'first one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _kTextGrey, fontSize: 13.5),
                        ),
                      ),
                    )
                  : results.isEmpty
                  ? _noMatchPrompt(
                      label: _searchController.text.trim(),
                      onCreate: () => _createCategory(
                        initialName: _searchController.text.trim(),
                      ),
                      itemNoun: 'category',
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final c = results[index];
                        final checked = _selected.contains(c.id);
                        return CheckboxListTile(
                          value: checked,
                          contentPadding: EdgeInsets.zero,
                          activeColor: kAccent,
                          controlAffinity: ListTileControlAffinity.trailing,
                          secondary: CategoryIcon(category: c, size: 42),
                          title: Text(
                            c.name,
                            style: const TextStyle(
                              color: _kTextDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(c.id);
                            } else {
                              _selected.remove(c.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                CategoryPickResult(selected: _selected, categories: _categories),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _selected.isEmpty
                    ? 'Done'
                    : 'Done  (${_selected.length} selected)',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCategorySheet extends StatefulWidget {
  const _NewCategorySheet({this.initialName});

  final String? initialName;

  @override
  State<_NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends State<_NewCategorySheet> {
  late final _nameController = TextEditingController(text: widget.initialName);
  String? _iconKey;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await showDialog<CategoryIconOption>(
      context: context,
      builder: (context) => const IconPickerDialog(),
    );
    if (result != null) setState(() => _iconKey = result.key);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter the category name');
      return;
    }
    if (_iconKey == null) {
      setState(() => _error = 'Choose an icon for the category');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await CategoryApiService.createCategory(
        name: name,
        iconPath: _iconKey!,
      );
      final id = (result['CategoryID'] as num).toInt();
      if (!mounted) return;
      Navigator.pop(
        context,
        CategoryModel(id: id, name: name, iconPath: _iconKey),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save the category: ${friendlyError(e)}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _nameController.text.trim().isEmpty
        ? kAccent
        : categoryColorFor(_nameController.text.trim());
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHandle(),
            const Text(
              'New category',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _pickIcon,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _kBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _iconKey == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: color,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Icon',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Icon(iconForKey(_iconKey!), color: color, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration('Category name').copyWith(
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: _kRed, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Save category',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
