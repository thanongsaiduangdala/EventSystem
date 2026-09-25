import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:ticket_com/HomePage/event_form_editors.dart';
import 'package:ticket_com/map/location_picker_page.dart';
import 'package:ticket_com/models/sponser_models.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/category_api_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/event_question_api_service.dart';
import 'package:ticket_com/services/sponser_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';
import 'package:ticket_com/utils/category_icons.dart';

const Color _kLavender = Color(0xFFEFEEFC);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kBorder = Color(0xFFE9E8F8);
const Color _kAmber = Color(0xFFB26A00);
const Color _kRed = Color(0xFFE53935);

/// The backend rejects images over 5 MB (see EventImageInfo_controllers.py).
const int _kMaxImageBytes = 5 * 1024 * 1024;
const int _kMaxPhotos = 8;

/// Create or edit an [EventModel]. Visually mirrors [EventDetailPage] (hero
/// header, icon-tile info rows, "About" section, floating action bar) but
/// every value shown there is an editable field here.
///
/// Besides the core event fields the organizer can also set up, in the same
/// form: photos (with a cover), categories, sponsors, ticket types and the
/// questions attendees answer at checkout. Returns `true` via Navigator.pop
/// when anything was saved so the caller can refresh its list.
class EventFormPage extends StatefulWidget {
  const EventFormPage({super.key, this.event, this.organizerId});

  final EventModel? event;

  /// When creating an event, pre-select this organizer (e.g. the organizer
  /// that owns the current account's dashboard).
  final int? organizerId;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _picker = ImagePicker();

  DateTime? _startDateTime;
  DateTime? _endDateTime;

  List<EventOrganizer> _organizers = [];
  bool _loadingOrganizers = true;
  int? _selectedOrganizerId;

  bool _onePerPerson = false;
  bool _isSubmitting = false;

  /// Set for an existing event, and also right after a brand-new event has
  /// been created -- so if a later step fails and the organizer retries, we
  /// update this event instead of creating a duplicate.
  int? _eventId;

  /// True once anything has reached the server; the dashboard then reloads.
  bool _hasSavedSomething = false;

  // ---- lookups (things the organizer picks from) ----
  bool _loadingLookups = true;
  String? _lookupError;
  List<CategoryModel> _categories = [];
  List<SponserModel> _sponsors = [];
  List<EventQuestionTypeModel> _questionTypes = [];

  // ---- what the organizer has chosen / entered ----
  final Set<int> _selectedCategoryIds = {};
  final Set<int> _selectedSponsorIds = {};
  final List<EventImageDraft> _images = [];
  final List<int> _deletedImageIds = [];
  int? _serverCoverId;
  final List<TicketTypeDraft> _tickets = [];
  final List<int> _deletedTicketIds = [];
  final List<QuestionDraft> _questions = [];
  final List<int> _deletedQuestionIds = [];

  // ---- loading the current details of an event being edited ----
  bool _existingReady = true;
  bool _loadingExisting = false;
  String? _existingError;

  bool get _isEditing => _eventId != null;

  EventOrganizer? get _selectedOrganizer {
    final id = _selectedOrganizerId;
    if (id == null) return null;
    for (final o in _organizers) {
      if (o.id == id) return o;
    }
    return null;
  }

  EventImageDraft? get _coverDraft {
    for (final d in _images) {
      if (d.isCover) return d;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    if (ev != null) {
      _eventId = ev.id;
      _nameController.text = ev.name;
      _addressController.text = ev.address;
      _descriptionController.text = ev.description;
      _latitudeController.text = ev.latitude.toString();
      _longitudeController.text = ev.longitude.toString();
      _startDateTime = ev.start;
      _endDateTime = ev.end;
      _selectedOrganizerId = ev.organizerId;
      _onePerPerson = ev.onePerPerson;
      _existingReady = false;
    } else {
      _selectedOrganizerId = widget.organizerId;
    }
    _loadOrganizers();
    _loadLookups();
    if (ev != null) _loadExisting();

    // The permission list in the saved session can be stale (e.g. an admin
    // changed the organizer role after login), so refresh it quietly.
    AuthService.refreshRbac()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizers() async {
    setState(() => _loadingOrganizers = true);
    try {
      final organizers = await EventApiService.getAllOrganizers();
      final session = AuthService.currentSession;
      final visible = session != null && !session.isSuperAdmin
          ? organizers
                .where((o) => o.createdByAccountId == session.accountId)
                .toList()
          : organizers;
      if (!mounted) return;
      setState(() {
        _organizers = visible;
        if (_selectedOrganizerId != null &&
            !_organizers.any((o) => o.id == _selectedOrganizerId)) {
          _selectedOrganizerId = null;
        }
      });
    } catch (e) {
      _snack('Failed to load organizers: $e');
    } finally {
      if (mounted) setState(() => _loadingOrganizers = false);
    }
  }

  /// Categories, sponsors and question types -- the lists the organizer
  /// picks from. Each one is loaded independently so one failure doesn't
  /// hide the others.
  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });
    final problems = <String>[];

    Future<T> guard<T>(String label, Future<T> future, T fallback) async {
      try {
        return await future;
      } catch (e) {
        problems.add('$label (${friendlyError(e)})');
        return fallback;
      }
    }

    final results = await Future.wait<Object>([
      guard<List<CategoryModel>>(
        'categories',
        CategoryApiService.getAllCategories(),
        <CategoryModel>[],
      ),
      guard<List<SponserModel>>(
        'sponsors',
        SponserApiService.getAllSponsers(),
        <SponserModel>[],
      ),
      guard<List<EventQuestionTypeModel>>(
        'question types',
        EventQuestionApiService.getAllEventQuestionTypes(),
        <EventQuestionTypeModel>[],
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<CategoryModel>;
      _sponsors = results[1] as List<SponserModel>;
      _questionTypes = results[2] as List<EventQuestionTypeModel>;
      _lookupError = problems.isEmpty
          ? null
          : "Couldn't load ${problems.join('; ')}.";
      _loadingLookups = false;
    });
  }

  /// When editing: fetch what is already attached to this event so it can be
  /// shown, changed and saved back.
  Future<void> _loadExisting() async {
    final eventId = _eventId;
    if (eventId == null) return;
    setState(() {
      _loadingExisting = true;
      _existingError = null;
    });
    try {
      final results = await Future.wait<Object>([
        EventImageApiService.getAllEventImages(),
        CategoryApiService.getCategoriesByEventId(eventId),
        SponserApiService.getAllEventSponsers(),
        TicketTypeApiService.getTicketTypesByEvent(eventId),
        EventQuestionApiService.getEventQuestionsByEvent(eventId),
      ]);
      final images = (results[0] as List<EventImageModel>)
          .where((i) => i.eventId == eventId)
          .toList();
      images.sort((a, b) {
        if (a.isThumbnail != b.isThumbnail) return a.isThumbnail ? -1 : 1;
        return a.id.compareTo(b.id);
      });
      final categoryLinks = results[1] as List<EventCategoryModel>;
      final sponsorLinks = (results[2] as List<EventSponserModel>)
          .where((l) => l.eventId == eventId)
          .toList();
      final tickets = results[3] as List<TicketTypeModel>;
      final questions = List<EventQuestionModel>.of(
        results[4] as List<EventQuestionModel>,
      );
      questions.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (!mounted) return;
      setState(() {
        _images
          ..clear()
          ..addAll([
            for (var i = 0; i < images.length; i++)
              EventImageDraft(
                id: images[i].id,
                path: images[i].imagePath,
                // The app treats the first image as the cover when none is
                // flagged, so mirror that here.
                isCover: i == 0,
              ),
          ]);
        _serverCoverId = images.isEmpty ? null : images.first.id;
        _selectedCategoryIds
          ..clear()
          ..addAll(categoryLinks.map((l) => l.categoryId));
        _selectedSponsorIds
          ..clear()
          ..addAll(sponsorLinks.map((l) => l.sponserId));
        _tickets
          ..clear()
          ..addAll(tickets.map(TicketTypeDraft.fromModel));
        _questions
          ..clear()
          ..addAll(questions.map(QuestionDraft.fromModel));
        _deletedImageIds.clear();
        _deletedTicketIds.clear();
        _deletedQuestionIds.clear();
        _existingReady = true;
        _loadingExisting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _existingError = friendlyError(e);
        _loadingExisting = false;
      });
    }
  }

  Future<void> _pickStart() async {
    final picked = await pickDateTime(context, _startDateTime);
    if (picked != null && mounted) setState(() => _startDateTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await pickDateTime(context, _endDateTime ?? _startDateTime);
    if (picked != null && mounted) setState(() => _endDateTime = picked);
  }

  Future<void> _pickOrganizer() async {
    if (_loadingOrganizers) return;
    if (_organizers.isEmpty) {
      _snack('No organizers exist yet. Create an organizer first.');
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select organizer',
                style: TextStyle(
                  color: _kTextDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              for (final o in _organizers)
                ListTile(
                  leading: _organizerAvatar(o, size: 36),
                  title: Text(
                    o.name,
                    style: const TextStyle(
                      color: _kTextDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: o.id == _selectedOrganizerId
                      ? const Icon(Icons.check, color: kAccent)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, o.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _selectedOrganizerId = picked);
  }

  bool _validateCoords(String? raw, {bool isLat = false}) {
    if (raw == null || raw.trim().isEmpty) return false;
    final value = double.tryParse(raw.trim());
    if (value == null) return false;
    if (isLat && (value < -90 || value > 90)) return false;
    if (!isLat && (value < -180 || value > 180)) return false;
    return true;
  }

  // ---------------- photos ----------------

  Future<void> _addPhotos() async {
    if (_images.length >= _kMaxPhotos) {
      _snack('You can add up to $_kMaxPhotos photos.');
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      var skipped = 0;
      for (final file in picked) {
        if (_images.length >= _kMaxPhotos) {
          skipped++;
          continue;
        }
        final bytes = await file.readAsBytes();
        if (bytes.length > _kMaxImageBytes) {
          skipped++;
          continue;
        }
        _images.add(
          EventImageDraft(
            bytes: bytes,
            filename:
                'event_${DateTime.now().millisecondsSinceEpoch}_${_images.length}'
                '.${imageExtensionFor(bytes)}',
            isCover: _coverDraft == null,
          ),
        );
      }
      if (!mounted) return;
      setState(() {});
      if (skipped > 0) {
        _snack(
          '$skipped photo(s) skipped. Each photo must be under 5 MB, '
          'with at most $_kMaxPhotos per event.',
        );
      }
    } catch (e) {
      _snack("Couldn't open your photos: ${friendlyError(e)}");
    }
  }

  void _removePhoto(EventImageDraft draft) {
    setState(() {
      _images.remove(draft);
      final id = draft.id;
      if (id != null) {
        _deletedImageIds.add(id);
        if (_serverCoverId == id) _serverCoverId = null;
      }
      if (draft.isCover && _images.isNotEmpty) _images.first.isCover = true;
    });
  }

  void _setCover(EventImageDraft draft) {
    setState(() {
      for (final d in _images) {
        d.isCover = identical(d, draft);
      }
    });
  }

  // ---------------- categories & sponsors ----------------

  Future<void> _pickCategories() async {
    final result = await showCategoryPickerSheet(
      context,
      categories: _categories,
      selected: _selectedCategoryIds,
    );
    if (result == null || !mounted) return;
    setState(() {
      _categories = result.categories;
      _selectedCategoryIds
        ..clear()
        ..addAll(result.selected);
    });
  }

  Future<void> _pickSponsors() async {
    final result = await showSponsorPickerSheet(
      context,
      sponsors: _sponsors,
      selected: _selectedSponsorIds,
    );
    if (result == null || !mounted) return;
    setState(() {
      _sponsors = result.sponsors;
      _selectedSponsorIds
        ..clear()
        ..addAll(result.selected);
    });
  }

  // ---------------- ticket types ----------------

  Future<void> _addTicket() async {
    final draft = await showTicketTypeSheet(
      context,
      eventStart: _startDateTime,
    );
    if (draft != null && mounted) setState(() => _tickets.add(draft));
  }

  Future<void> _editTicket(int index) async {
    final draft = await showTicketTypeSheet(
      context,
      initial: _tickets[index],
      eventStart: _startDateTime,
    );
    if (draft != null && mounted) setState(() => _tickets[index] = draft);
  }

  void _removeTicket(int index) {
    setState(() {
      final removed = _tickets.removeAt(index);
      if (removed.id != null) _deletedTicketIds.add(removed.id!);
    });
  }

  // ---------------- questions ----------------

  Future<void> _addQuestion() async {
    if (_questionTypes.isEmpty) {
      _snack("Question types haven't loaded. Tap Retry at the top first.");
      return;
    }
    final draft = await showQuestionSheet(context, types: _questionTypes);
    if (draft != null && mounted) setState(() => _questions.add(draft));
  }

  Future<void> _editQuestion(int index) async {
    final draft = await showQuestionSheet(
      context,
      types: _questionTypes,
      initial: _questions[index],
    );
    if (draft != null && mounted) setState(() => _questions[index] = draft);
  }

  void _moveQuestion(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _questions.length) return;
    setState(() {
      final q = _questions.removeAt(index);
      _questions.insert(target, q);
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      final removed = _questions.removeAt(index);
      if (removed.id != null) _deletedQuestionIds.add(removed.id!);
    });
  }

  String _questionTypeName(int typeId) {
    for (final t in _questionTypes) {
      if (t.id == typeId) return t.name;
    }
    return 'Type #$typeId';
  }

  // ---------------- saving ----------------

  int? _readId(Map<String, dynamic> response, List<String> keys) {
    for (final key in keys) {
      final v = response[key];
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSubmitting) return;
    if (!_existingReady) {
      _snack(
        "This event's current details haven't loaded yet. "
        'Tap Retry at the top, then save.',
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _snack('Fill in the event name and description');
      return;
    }
    if (_startDateTime == null || _endDateTime == null) {
      _snack('Select both start and end date/time');
      return;
    }
    if (!_endDateTime!.isAfter(_startDateTime!)) {
      _snack('The event must end after it starts');
      return;
    }
    if (_selectedOrganizerId == null) {
      _snack('Select the organizer for this event');
      return;
    }
    if (!_validateCoords(_latitudeController.text, isLat: true) ||
        !_validateCoords(_longitudeController.text)) {
      _snack('Enter valid coordinates for the event location');
      return;
    }

    setState(() => _isSubmitting = true);

    // Step 1: the event itself.
    try {
      final start = formatDateTimeForApi(_startDateTime!);
      final end = formatDateTimeForApi(_endDateTime!);
      final lat = double.parse(_latitudeController.text.trim());
      final lng = double.parse(_longitudeController.text.trim());
      if (_eventId != null) {
        await EventApiService.updateEvent(
          eventId: _eventId!,
          eventName: _nameController.text.trim(),
          eventStartingYMDT: start,
          eventEndingYMDT: end,
          eventAddress: _addressController.text.trim(),
          latitude: lat,
          longitude: lng,
          eventDescription: _descriptionController.text.trim(),
          eventOrganizerID: _selectedOrganizerId!,
          onePerPerson: _onePerPerson,
        );
      } else {
        final created = await EventApiService.createEvent(
          eventName: _nameController.text.trim(),
          eventStartingYMDT: start,
          eventEndingYMDT: end,
          eventAddress: _addressController.text.trim(),
          latitude: lat,
          longitude: lng,
          eventDescription: _descriptionController.text.trim(),
          eventOrganizerID: _selectedOrganizerId!,
          onePerPerson: _onePerPerson,
        );
        final newId = _readId(created, ['event_id', 'EventID']);
        if (newId == null) {
          throw Exception('The server did not return the new event id.');
        }
        _eventId = newId;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _snack('Save failed: ${friendlyError(e)}');
      return;
    }
    if (!mounted) return;
    setState(() => _hasSavedSomething = true);

    // Step 2: everything attached to the event. Each part is independent, so
    // one failing (say, a missing permission) doesn't lose the others.
    final problems = <String>[];
    Future<void> step(String label, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        problems.add('$label: ${friendlyError(e)}');
      }
    }

    await step('Categories', _syncCategories);
    await step('Sponsors', _syncSponsors);
    await step('Ticket types', _syncTicketTypes);
    await step('Questions', _syncQuestions);
    await step('Photos', _syncImages);

    if (!mounted) return;
    if (problems.isEmpty) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _isSubmitting = false);
    await _showSaveProblems(problems);
  }

  Future<void> _syncCategories() async {
    final eventId = _eventId!;
    final existing = await CategoryApiService.getCategoriesByEventId(eventId);
    final linked = <int>{};
    for (final link in existing) {
      if (_selectedCategoryIds.contains(link.categoryId)) {
        linked.add(link.categoryId);
      } else {
        await CategoryApiService.deleteEventCategoryLink(link.id);
      }
    }
    for (final categoryId in _selectedCategoryIds) {
      if (!linked.contains(categoryId)) {
        await CategoryApiService.linkEventCategory(
          eventId: eventId,
          categoryId: categoryId,
        );
      }
    }
  }

  Future<void> _syncSponsors() async {
    final eventId = _eventId!;
    final all = await SponserApiService.getAllEventSponsers();
    final linked = <int>{};
    for (final link in all.where((l) => l.eventId == eventId)) {
      if (_selectedSponsorIds.contains(link.sponserId)) {
        linked.add(link.sponserId);
      } else {
        await SponserApiService.deleteEventSponserLink(link.id);
      }
    }
    for (final sponsorId in _selectedSponsorIds) {
      if (!linked.contains(sponsorId)) {
        await SponserApiService.linkEventSponser(
          eventId: eventId,
          sponserId: sponsorId,
        );
      }
    }
  }

  Future<void> _syncTicketTypes() async {
    final eventId = _eventId!;
    for (final id in List<int>.of(_deletedTicketIds)) {
      await TicketTypeApiService.deleteTicketType(id);
      _deletedTicketIds.remove(id);
    }
    for (final t in _tickets) {
      if (t.id == null) {
        final created = await TicketTypeApiService.createTicketType(
          eventId: eventId,
          typeName: t.name,
          priceInKip: t.price,
          capacity: t.capacity,
          saleStart: formatDateTimeForApi(t.saleStart),
          saleEnd: formatDateTimeForApi(t.saleEnd),
        );
        final id = _readId(created, ['TicketTypeID', 'event_id']);
        if (id == null) {
          throw Exception('The server did not return the new ticket type id.');
        }
        t.id = id;
        t.dirty = false;
      } else if (t.dirty) {
        await TicketTypeApiService.updateTicketType(
          ticketTypeId: t.id!,
          eventId: eventId,
          typeName: t.name,
          priceInKip: t.price,
          capacity: t.capacity,
          saleStart: formatDateTimeForApi(t.saleStart),
          saleEnd: formatDateTimeForApi(t.saleEnd),
        );
        t.dirty = false;
      }
    }
  }

  Future<void> _syncQuestions() async {
    final eventId = _eventId!;
    for (final id in List<int>.of(_deletedQuestionIds)) {
      await EventQuestionApiService.deleteEventQuestion(id);
      _deletedQuestionIds.remove(id);
    }
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final order = i + 1;
      final options = kOptionQuestionTypeIds.contains(q.typeId)
          ? List<String>.of(q.options)
          : null;
      if (q.id == null) {
        final created = await EventQuestionApiService.createEventQuestion(
          eventId: eventId,
          question: q.text,
          questionTypeId: q.typeId,
          isRequire: q.isRequired,
          sortOrder: order,
          options: options,
        );
        final id = _readId(created, ['EventQuestionID']);
        if (id == null) {
          throw Exception('The server did not return the new question id.');
        }
        q.id = id;
        q.serverSort = order;
        q.dirty = false;
      } else if (q.dirty || q.serverSort != order) {
        await EventQuestionApiService.updateEventQuestion(
          eventQuestionId: q.id!,
          eventId: eventId,
          question: q.text,
          questionTypeId: q.typeId,
          isRequire: q.isRequired,
          sortOrder: order,
          options: options,
        );
        q.serverSort = order;
        q.dirty = false;
      }
    }
  }

  Future<void> _syncImages() async {
    final eventId = _eventId!;
    for (final id in List<int>.of(_deletedImageIds)) {
      await EventImageApiService.deleteEventImage(id);
      _deletedImageIds.remove(id);
    }
    for (final d in _images) {
      if (d.id == null && d.bytes != null) {
        final uploaded = await EventImageApiService.uploadEventImage(
          eventId: eventId,
          bytes: d.bytes!,
          filename: d.filename ?? 'event.jpg',
        );
        final id = _readId(uploaded, ['Image_ID', 'ImageID']);
        if (id == null) {
          throw Exception('The server did not return the new image id.');
        }
        d.id = id;
        d.path = uploaded['ImagePath']?.toString();
      }
    }
    final cover = _coverDraft;
    if (cover?.id != null && cover!.id != _serverCoverId) {
      await EventImageApiService.setThumbnail(cover.id!);
      _serverCoverId = cover.id;
    }
  }

  Future<void> _showSaveProblems(List<String> problems) async {
    final closeAnyway = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Event saved, but not everything',
          style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your event was saved, but these parts could not be:',
                style: TextStyle(color: _kTextGrey, fontSize: 13.5),
              ),
              const SizedBox(height: 10),
              for (final p in problems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '\u2022 $p',
                    style: const TextStyle(color: _kTextDark, fontSize: 13.5),
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                'Everything that did save is kept. Fix and save again to '
                'retry only the rest.',
                style: TextStyle(color: _kTextGrey, fontSize: 12.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            child: const Text('Fix & retry'),
          ),
        ],
      ),
    );
    if (closeAnyway == true && mounted) Navigator.pop(context, true);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Once the event exists on the server, leaving must tell the dashboard
      // to refresh -- even if the organizer backs out after a partial save.
      canPop: !_hasSavedSomething,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [_heroWithNameCard(context), _body(context)],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
              child: _saveBar(context),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- hero ----------------

  Widget _heroWithNameCard(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _hero(context),
        Positioned(left: 20, right: 20, bottom: -30, child: _nameCard()),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final cover = _coverDraft;
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kAccent, Color(0xFF8E2DE2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: cover == null
                ? const Icon(Icons.event, color: Colors.white24, size: 72)
                : null,
          ),
          if (cover != null) ...[
            Positioned.fill(child: _draftImage(cover, thumb: false)),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x8A000000), Color(0x00000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
          ],
          Positioned(
            top: topPad + 12,
            left: 8,
            child: Row(
              children: [
                _circleIconButton(
                  icon: Icons.arrow_back_ios_new,
                  onTap: () =>
                      Navigator.pop(context, _hasSavedSomething ? true : null),
                ),
                const SizedBox(width: 10),
                Text(
                  _isEditing ? 'Edit Event' : 'Create Event',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topPad + 12,
            right: 12,
            child: _circleIconButton(
              icon: Icons.photo_camera_outlined,
              onTap: _addPhotos,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _nameCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextFormField(
        controller: _nameController,
        style: const TextStyle(
          color: _kTextDark,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: 'Event name',
          hintStyle: TextStyle(
            color: _kTextGrey,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Enter the event name' : null,
      ),
    );
  }

  // ---------------- body ----------------

  Widget _body(BuildContext context) {
    final notice = _permissionNotice();
    final loadIssue = _loadIssueBanner();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loadIssue != null) ...[loadIssue, const SizedBox(height: 16)],
          _dateRow(),
          const SizedBox(height: 16),
          _locationRow(),
          const SizedBox(height: 16),
          _organizerRow(),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _onePerPerson,
            onChanged: (v) => setState(() => _onePerPerson = v),
            title: const Text(
              'One ticket per person',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'Each attendee can only buy one ticket',
              style: TextStyle(color: _kTextGrey, fontSize: 12),
            ),
            activeThumbColor: kAccent,
          ),
          const SizedBox(height: 20),
          _aboutSection(),
          if (notice != null) ...[const SizedBox(height: 20), notice],
          _sectionDivider(),
          _photosSection(),
          _sectionDivider(),
          _categoriesSection(),
          _sectionDivider(),
          _sponsorsSection(),
          _sectionDivider(),
          _ticketTypesSection(),
          _sectionDivider(),
          _questionsSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  /// Warns when the account is missing a permission the backend enforces on
  /// one of the sections below, instead of failing silently at save time.
  Widget? _permissionNotice() {
    final session = AuthService.currentSession;
    if (session == null || session.isSuperAdmin) return null;
    final missing = <String>[
      if (!session.hasPermission(Permissions.manageEventImages)) 'photos',
      if (!session.hasPermission(Permissions.manageCategories)) 'categories',
      if (!session.hasPermission(Permissions.manageTicketTypes)) 'ticket types',
      if (!session.hasPermission(Permissions.manageEventQuestions)) 'questions',
    ];
    if (missing.isEmpty) return null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: _kAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Your account isn't allowed to save ${missing.join(', ')} yet. "
              'The event itself will save, but those parts will be rejected '
              'until an admin enables them for the Organizer role.',
              style: const TextStyle(
                color: _kAmber,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _loadIssueBanner() {
    final message = _existingError != null
        ? "Couldn't load this event's photos, tickets and questions: "
              '$_existingError'
        : _lookupError;
    if (message == null) {
      if (!_loadingExisting) return null;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kLavender,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: kAccent),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading this event\u2019s photos, tickets and questions\u2026',
                style: TextStyle(color: kAccent, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _kRed, fontSize: 12.5, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: () {
              if (_existingError != null) _loadExisting();
              if (_lookupError != null) _loadLookups();
            },
            child: const Text(
              'Retry',
              style: TextStyle(color: _kRed, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconTile(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _kLavender,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(child: Icon(icon, color: kAccent, size: 20)),
    );
  }

  Widget _dateRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconTile(Icons.calendar_today_outlined),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dateField('Starts', _startDateTime, _pickStart),
              const SizedBox(height: 10),
              _dateField('Ends', _endDateTime, _pickEnd),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              label,
              style: const TextStyle(color: _kTextGrey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value == null ? 'Select date & time' : formatDateTime(value),
              style: TextStyle(
                color: value == null ? _kTextGrey : _kTextDark,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E), size: 18),
        ],
      ),
    );
  }

  Widget _locationRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconTile(Icons.location_on_outlined),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _addressController,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Event location / address',
                  hintStyle: TextStyle(color: _kTextGrey, fontSize: 15),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter the event address'
                    : null,
              ),
              const SizedBox(height: 10),
              _mapPicker(),
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasCoords =>
      double.tryParse(_latitudeController.text) != null &&
      double.tryParse(_longitudeController.text) != null;

  Widget _mapPicker() {
    return GestureDetector(
      onTap: _pickLocationOnMap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9E8F8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _hasCoords ? _mapPreview() : _mapPlaceholder(),
      ),
    );
  }

  Widget _mapPreview() {
    final point = LatLng(
      double.parse(_latitudeController.text),
      double.parse(_longitudeController.text),
    );
    return Stack(
      children: [
        SizedBox(
          height: 130,
          width: double.infinity,
          child: IgnorePointer(
            child: FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.reservation_system',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        color: Color(0xFFE53935),
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'Change location',
              style: TextStyle(
                color: kAccent,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapPlaceholder() {
    return Container(
      height: 90,
      width: double.infinity,
      color: _kLavender,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, color: kAccent, size: 24),
          SizedBox(height: 6),
          Text(
            'Tap to set location on map',
            style: TextStyle(
              color: kAccent,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLocationOnMap() async {
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerPage(
          initialLocation: lat != null && lng != null ? LatLng(lat, lng) : null,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _latitudeController.text = picked.latitude.toStringAsFixed(6);
      _longitudeController.text = picked.longitude.toStringAsFixed(6);
    });
  }

  Widget _organizerRow() {
    return GestureDetector(
      onTap: _pickOrganizer,
      child: Row(
        children: [
          _loadingOrganizers
              ? _iconTile(Icons.hourglass_empty)
              : (_selectedOrganizer == null
                    ? _iconTile(Icons.storefront_outlined)
                    : _organizerAvatar(_selectedOrganizer!, size: 44)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedOrganizer?.name ?? 'Select organizer',
                  style: TextStyle(
                    color: _selectedOrganizer == null ? _kTextGrey : _kTextDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Organizer',
                  style: TextStyle(color: _kTextGrey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
        ],
      ),
    );
  }

  Widget _organizerAvatar(EventOrganizer organizer, {required double size}) {
    final name = organizer.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kAccent,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _aboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About Event',
          style: TextStyle(
            color: _kTextDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _descriptionController,
          maxLines: 6,
          minLines: 3,
          style: const TextStyle(color: _kTextGrey, fontSize: 14, height: 1.55),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: 'Describe the event',
            hintStyle: TextStyle(color: _kTextGrey, fontSize: 14),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter a description' : null,
        ),
      ],
    );
  }

  // ---------------- new sections ----------------

  Widget _sectionDivider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 22),
    child: Divider(color: Color(0xFFF0F0F5), height: 1),
  );

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconTile(icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _kTextGrey,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _addButton(String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccent,
        side: const BorderSide(color: kAccent),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      text,
      style: const TextStyle(color: _kTextGrey, fontSize: 12.5, height: 1.4),
    ),
  );

  // ----- photos -----

  Widget _draftImage(EventImageDraft d, {required bool thumb}) {
    final bytes = d.bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: thumb ? 300 : null,
      );
    }
    final path = d.path ?? '';
    final full = EventImageApiService.fullImageUrl(path);
    final url = thumb ? EventImageApiService.thumbnailUrl(path) : full;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        if (thumb) {
          return Image.network(
            full,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _brokenImage(),
          );
        }
        return _brokenImage();
      },
    );
  }

  Widget _brokenImage() => Container(
    color: _kLavender,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined, color: _kTextGrey),
  );

  Widget _photosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.photo_library_outlined,
          title: 'Photos',
          subtitle: 'Add up to $_kMaxPhotos. The cover photo is shown first.',
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 112,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _addPhotoTile(),
              for (final d in _images) _photoTile(d),
            ],
          ),
        ),
        if (_images.isEmpty)
          _hint('Events with a photo get noticed much more. Tap to add one.'),
      ],
    );
  }

  Widget _addPhotoTile() {
    return GestureDetector(
      onTap: _addPhotos,
      child: Container(
        width: 112,
        decoration: BoxDecoration(
          color: _kLavender,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: kAccent, size: 28),
            SizedBox(height: 6),
            Text(
              'Add photos',
              style: TextStyle(
                color: kAccent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoTile(EventImageDraft d) {
    return Container(
      width: 112,
      margin: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: d.isCover ? kAccent : _kBorder,
          width: d.isCover ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _draftImage(d, thumb: true),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removePhoto(d),
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: d.isCover
                ? _photoBadge('Cover', kAccent, Colors.white)
                : GestureDetector(
                    onTap: () => _setCover(d),
                    child: _photoBadge('Set cover', Colors.white, kAccent),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _photoBadge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  // ----- categories -----

  Widget _categoriesSection() {
    final chosen = _categories
        .where((c) => _selectedCategoryIds.contains(c.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.category_outlined,
          title: 'Categories',
          subtitle: 'Help people find your event. Pick as many as fit.',
        ),
        const SizedBox(height: 14),
        if (_loadingLookups)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: kAccent),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final c in chosen) _categoryChip(c),
              _addButton(
                chosen.isEmpty ? 'Add categories' : 'Edit categories',
                _pickCategories,
              ),
            ],
          ),
      ],
    );
  }

  Widget _categoryChip(CategoryModel c) {
    final color = categoryColorFor(c.name);
    return Chip(
      avatar: Icon(iconForKey(c.iconPath ?? ''), size: 16, color: color),
      label: Text(
        c.name,
        style: const TextStyle(
          color: _kTextDark,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      onDeleted: () => setState(() => _selectedCategoryIds.remove(c.id)),
    );
  }

  // ----- sponsors -----

  Widget _sponsorsSection() {
    final chosen = _sponsors
        .where((s) => _selectedSponsorIds.contains(s.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.handshake_outlined,
          title: 'Sponsors',
          subtitle: 'Optional. Show the brands backing your event.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final s in chosen)
              Chip(
                avatar: SponsorLogo(sponsor: s, size: 24),
                label: Text(
                  s.name,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                backgroundColor: _kLavender,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                onDeleted: () =>
                    setState(() => _selectedSponsorIds.remove(s.id)),
              ),
            _addButton(
              chosen.isEmpty ? 'Add sponsors' : 'Edit sponsors',
              _pickSponsors,
            ),
          ],
        ),
      ],
    );
  }

  // ----- ticket types -----

  Widget _ticketTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.confirmation_number_outlined,
          title: 'Ticket types',
          subtitle: 'Price, capacity and when sales open. Add one per tier.',
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _tickets.length; i++) ...[
          _ticketCard(i, _tickets[i]),
          const SizedBox(height: 10),
        ],
        _addButton('Add ticket type', _addTicket),
        if (_tickets.isEmpty)
          _hint('Without a ticket type, nobody can buy tickets for this event.'),
      ],
    );
  }

  Widget _itemCard({required Widget leading, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _ticketCard(int index, TicketTypeDraft t) {
    return _itemCard(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _kLavender,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.confirmation_number_outlined,
          color: kAccent,
          size: 19,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${formatKip(t.price)}  \u00b7  ${t.capacity} tickets',
            style: const TextStyle(
              color: kAccent,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Sales ${formatDateTime(t.saleStart)} \u2192 '
            '${formatDateTime(t.saleEnd)}',
            style: const TextStyle(color: _kTextGrey, fontSize: 11.5),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit',
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF1E88E5),
              size: 20,
            ),
            onPressed: () => _editTicket(index),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline, color: _kRed, size: 20),
            onPressed: () => _removeTicket(index),
          ),
        ],
      ),
    );
  }

  // ----- questions -----

  Widget _questionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.quiz_outlined,
          title: 'Event questions',
          subtitle: 'Optional. Ask attendees things like dietary needs or '
              'T-shirt size when they buy.',
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _questions.length; i++) ...[
          _questionCard(i, _questions[i]),
          const SizedBox(height: 10),
        ],
        _addButton('Add question', _addQuestion),
      ],
    );
  }

  Widget _questionCard(int index, QuestionDraft q) {
    final showsOptions =
        kOptionQuestionTypeIds.contains(q.typeId) && q.options.isNotEmpty;
    return _itemCard(
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kLavender,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: kAccent,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_questionTypeName(q.typeId)}  \u00b7  '
            '${q.isRequired ? 'Required' : 'Optional'}',
            style: const TextStyle(
              color: kAccent,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showsOptions) ...[
            const SizedBox(height: 2),
            Text(
              q.options.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kTextGrey, fontSize: 11.5),
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Options',
        icon: const Icon(Icons.more_vert, color: _kTextGrey, size: 20),
        color: Colors.white,
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _editQuestion(index);
            case 'up':
              _moveQuestion(index, -1);
            case 'down':
              _moveQuestion(index, 1);
            case 'delete':
              _removeQuestion(index);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (index > 0) const PopupMenuItem(value: 'up', child: Text('Move up')),
          if (index < _questions.length - 1)
            const PopupMenuItem(value: 'down', child: Text('Move down')),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Remove', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
  }

  // ---------------- save bar ----------------

  Widget _saveBar(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: kAccent.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(30),
      color: kAccent,
      child: InkWell(
        onTap: _isSubmitting ? null : _save,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        (_isEditing ? 'Save Changes' : 'Submit Event')
                            .toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
              Container(
                margin: const EdgeInsets.all(7),
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isEditing ? Icons.check : Icons.arrow_forward,
                  color: kAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}
