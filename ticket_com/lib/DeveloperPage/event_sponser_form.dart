import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../services/event_api_service.dart';
import '../services/sponser_api_service.dart';
import '../models/sponser_models.dart';
import './SearchDialog/event_search_dialog.dart';
import './SearchDialog/sponser_search_dialog.dart';
import './square_crop_page.dart';

class EventSponserForm extends StatefulWidget {
  const EventSponserForm({super.key});

  @override
  State<EventSponserForm> createState() => EventSponserFormState();
}

class EventSponserFormState extends State<EventSponserForm> {
  final _formKey = GlobalKey<FormState>();

  final _sponserNameController = TextEditingController();
  final _picker = ImagePicker();

  // A newly picked (and possibly cropped) logo, held as bytes.
  Uint8List? _pickedLogoBytes;
  String? _pickedLogoName;
  // The logo path already stored on the server, shown as a preview while
  // editing if the user hasn't picked a replacement.
  String? _existingLogoPath;

  List<EventModel> _events = [];
  int? _selectedEventId;
  bool _loadingEvents = false;

  List<SponserModel> _sponsers = [];
  bool _loadingSponsers = false;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingEventSponserId; // the Event<->Sponsor link being edited
  int? _editingSponserId; // the underlying sponsor being edited/reused

  List<EventSponserModel> _links = [];
  bool _loadingLinks = false;
  final _linkSearchController = TextEditingController();
  List<EventSponserModel> _filteredLinks = [];
  int? _filterEventId; // null = "All Events"

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadSponsers();
  }

  @override
  void dispose() {
    _sponserNameController.dispose();
    _linkSearchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final events = await EventApiService.getAllEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        if (_selectedEventId != null &&
            !_events.any((e) => e.id == _selectedEventId)) {
          _selectedEventId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> reloadEvents() => _loadEvents();

  Future<void> _loadSponsers() async {
    setState(() => _loadingSponsers = true);
    try {
      final sponsers = await SponserApiService.getAllSponsers();
      if (!mounted) return;
      setState(() => _sponsers = sponsers);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load sponsors: $e')));
    } finally {
      if (mounted) setState(() => _loadingSponsers = false);
    }
  }

  // Backend only supports fetching every link, so pull the full list and
  // filter locally by event and/or search text -- same approach as images.
  Future<void> _loadLinks() async {
    setState(() => _loadingLinks = true);
    try {
      final data = await SponserApiService.getAllEventSponsers();
      if (!mounted) return;
      setState(() => _links = data);
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingLinks = false);
    }
  }

  Future<void> _onEventFilterChanged(int? eventId) async {
    setState(() => _filterEventId = eventId);
    _applyFilters();
  }

  Future<void> _openEventFilterSearch() async {
    final result = await showDialog<EventModel>(
      context: context,
      builder: (context) => EventSearchDialog(events: _events),
    );
    if (result != null) {
      await _onEventFilterChanged(result.id);
    }
  }

  // ---------------- helpers ----------------

  String _eventNameFor(int eventId) {
    final match = _events.where((e) => e.id == eventId);
    return match.isNotEmpty ? match.first.name : 'Event #$eventId';
  }

  SponserModel? _sponserFor(int sponserId) {
    final match = _sponsers.where((s) => s.id == sponserId);
    return match.isNotEmpty ? match.first : null;
  }

  void _applyFilters() {
    final q = _linkSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredLinks = _links.where((link) {
        final matchesEvent =
            _filterEventId == null || link.eventId == _filterEventId;
        final sponserName = _sponserFor(link.sponserId)?.name ?? '';
        final matchesQuery =
            q.isEmpty ||
            link.id.toString().contains(q) ||
            sponserName.toLowerCase().contains(q) ||
            _eventNameFor(link.eventId).toLowerCase().contains(q);
        return matchesEvent && matchesQuery;
      }).toList();
    });
  }

  void _filterLinks(String query) {
    _applyFilters();
  }

  Future<void> _openEventSearch() async {
    final result = await showDialog<EventModel>(
      context: context,
      builder: (context) => EventSearchDialog(events: _events),
    );
    if (result != null) {
      setState(() => _selectedEventId = result.id);
    }
  }

  Future<void> _openSponserSearch() async {
    final result = await showDialog<SponserModel>(
      context: context,
      builder: (context) => SponserSearchDialog(sponsers: _sponsers),
    );
    if (result != null) {
      setState(() {
        _editingSponserId = result.id;
        _sponserNameController.text = result.name;
        _existingLogoPath = result.logoPath;
        _pickedLogoBytes = null;
        _pickedLogoName = null;
      });
    }
  }

  void _clearSponserSelection() {
    setState(() {
      _editingSponserId = null;
      _sponserNameController.clear();
      _existingLogoPath = null;
      _pickedLogoBytes = null;
      _pickedLogoName = null;
    });
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadLinks();
  }

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

  void _startEditLink(EventSponserModel link) {
    final sponser = _sponserFor(link.sponserId);
    _sponserNameController.text = sponser?.name ?? '';

    setState(() {
      _editingEventSponserId = link.id;
      _editingSponserId = link.sponserId;
      _selectedEventId = link.eventId;
      _existingLogoPath = sponser?.logoPath;
      _pickedLogoBytes = null;
      _pickedLogoName = null;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _sponserNameController.clear();

    setState(() {
      _editingEventSponserId = null;
      _editingSponserId = null;
      _selectedEventId = null;
      _existingLogoPath = null;
      _pickedLogoBytes = null;
      _pickedLogoName = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteLink(EventSponserModel link) async {
    final sponser = _sponserFor(link.sponserId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Remove sponsor from event?',
          style: TextStyle(color: Color(0xFF212121)),
        ),
        content: Text(
          'This will remove "${sponser?.name ?? 'this sponsor'}" from '
          '"${_eventNameFor(link.eventId)}". The sponsor itself is not deleted.',
          style: const TextStyle(color: Color(0xFF757575)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await SponserApiService.deleteEventSponserLink(link.id);
        _loadLinks();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEventId == null) {
      _snack('Please select an event');
      return;
    }

    final name = _sponserNameController.text.trim();

    // Editing a reused sponsor changes the shared record everywhere it's
    // used, not just this event link -- confirm before overwriting it.
    if (_editingSponserId != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Update this sponsor?',
            style: TextStyle(color: Color(0xFF212121)),
          ),
          content: Text(
            'This changes the name/logo for '
            '"${_sponserFor(_editingSponserId!)?.name ?? 'this sponsor'}" '
            'everywhere it\'s used, not just this event. Continue?',
            style: const TextStyle(color: Color(0xFF757575)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Update',
                style: TextStyle(color: Color(0xFF5B4DFF)),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      int sponserId;

      if (_editingSponserId == null) {
        // New sponsor: logo is mandatory, there's nothing to point
        // SponserLogoPath at otherwise.
        if (_pickedLogoBytes == null) {
          _snack('Please upload a sponsor logo');
          return;
        }
        final result = await SponserApiService.uploadSponser(
          bytes: _pickedLogoBytes!,
          filename: _pickedLogoName ?? 'logo.jpg',
          name: name,
        );
        sponserId = result['Sponser_ID'] as int;
        _snack(result['msg']?.toString() ?? 'Sponsor created');
      } else if (_pickedLogoBytes != null) {
        // Editing an existing sponsor and picked a replacement file.
        final result = await SponserApiService.replaceSponserLogo(
          sponserId: _editingSponserId!,
          name: name,
          bytes: _pickedLogoBytes!,
          filename: _pickedLogoName ?? 'logo.jpg',
        );
        sponserId = _editingSponserId!;
        _snack(result['msg']?.toString() ?? 'Sponsor updated');
      } else {
        // Editing, no new file picked: just rename, keep the existing path.
        await SponserApiService.updateSponserNameOnly(
          sponserId: _editingSponserId!,
          name: name,
          logoPath: _existingLogoPath ?? '',
        );
        sponserId = _editingSponserId!;
        _snack('Sponsor updated');
      }

      // Create or update the Event<->Sponsor link.
      if (_editingEventSponserId == null) {
        await SponserApiService.linkEventSponser(
          eventId: _selectedEventId!,
          sponserId: sponserId,
        );
      } else {
        await SponserApiService.updateEventSponserLink(
          eventSponserId: _editingEventSponserId!,
          eventId: _selectedEventId!,
          sponserId: sponserId,
        );
      }

      await _loadSponsers();
      _startCreate();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF757575)),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x33000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5B4DFF), width: 1.6),
      ),
    );
  }

  Widget _buildLogoPreview() {
    Widget child;
    if (_pickedLogoBytes != null) {
      child = Image.memory(_pickedLogoBytes!, fit: BoxFit.cover);
    } else if (_existingLogoPath != null && _existingLogoPath!.isNotEmpty) {
      child = Image.network(
        SponserApiService.fullImageUrl(_existingLogoPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFF9E9E9E)),
        ),
      );
    } else {
      child = const Center(
        child: Icon(Icons.handshake_outlined, color: Color(0xFF9E9E9E), size: 40),
      );
    }

    // Square preview since the stored logo is always square.
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 160,
        width: 160,
        color: Color(0xFFF1F1F5),
        child: child,
      ),
    );
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
            if (_editingEventSponserId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Sponsor Link ID: $_editingEventSponserId',
                  style: const TextStyle(
                    color: Color(0xFF5B4DFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loadingEvents ? null : _openEventSearch,
                    child: InputDecorator(
                      decoration: _decoration('Event'),
                      child: Text(
                        _selectedEventId == null
                            ? (_loadingEvents
                                  ? 'Loading...'
                                  : 'Tap to search event')
                            : _eventNameFor(_selectedEventId!),
                        style: const TextStyle(color: Color(0xFF212121)),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadingEvents ? null : _loadEvents,
                  icon: _loadingEvents
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF757575),
                          ),
                        )
                      : const Icon(Icons.refresh, color: Color(0xFF757575)),
                  tooltip: 'Refresh event list',
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loadingSponsers ? null : _openSponserSearch,
                    child: InputDecorator(
                      decoration: _decoration(
                        'Use Existing Sponsor (optional)',
                      ),
                      child: Text(
                        _editingSponserId == null
                            ? (_loadingSponsers
                                  ? 'Loading...'
                                  : 'Tap to search existing sponsors')
                            : (_sponserFor(_editingSponserId!)?.name ??
                                  'Sponsor #$_editingSponserId'),
                        style: const TextStyle(color: Color(0xFF212121)),
                      ),
                    ),
                  ),
                ),
                if (_editingSponserId != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF757575)),
                    tooltip: 'Clear selected sponsor',
                    onPressed: _clearSponserSelection,
                  ),
                IconButton(
                  onPressed: _loadingSponsers ? null : _loadSponsers,
                  icon: IconButton(
                    onPressed: _loadingSponsers ? null : _loadSponsers,
                    icon: _loadingSponsers
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF757575),
                            ),
                          )
                        : const Icon(Icons.refresh, color: Color(0xFF757575)),
                    tooltip: 'Refresh sponsor list',
                  ),
                  tooltip: 'Refresh sponsor list',
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _sponserNameController,
              style: const TextStyle(color: Color(0xFF212121)),
              decoration: _decoration('Sponsor Name'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Sponsor name is required'
                  : null,
            ),
            const SizedBox(height: 16),

            const Text(
              'Sponsor Logo (must be square)',
              style: TextStyle(color: Color(0xFF757575)),
            ),
            const SizedBox(height: 8),
            _buildLogoPreview(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF212121),
              ),
              label: Text(
                _pickedLogoBytes == null && _existingLogoPath == null
                    ? 'Choose Logo'
                    : 'Choose Different Logo',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFF212121),
                side: const BorderSide(color: Color(0x33000000)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "If the picked image isn't square, you'll be asked to crop it before it's used.",
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5B4DFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _editingEventSponserId == null
                            ? 'Add Sponsor to Event'
                            : 'Update Sponsor',
                      ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _openTable,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF212121),
                  side: const BorderSide(color: Color(0x33000000)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('View / Manage Event Sponsors'),
              ),
            ),

            if (_editingEventSponserId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Add New Sponsor'),
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
                  onTap: _openEventFilterSearch,
                  child: InputDecorator(
                    decoration: _decoration('Filter by Event'),
                    child: Text(
                      _filterEventId == null
                          ? 'All Events -- tap to filter'
                          : _eventNameFor(_filterEventId!),
                      style: const TextStyle(color: Color(0xFF212121)),
                    ),
                  ),
                ),
              ),
              if (_filterEventId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF757575)),
                  tooltip: 'Clear event filter',
                  onPressed: () => _onEventFilterChanged(null),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF757575)),
                onPressed: _loadLinks,
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
            controller: _linkSearchController,
            onChanged: _filterLinks,
            style: const TextStyle(color: Color(0xFF212121)),
            decoration: InputDecoration(
              hintText: 'Search by ID or sponsor name',
              hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9E9E9E)),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0x33000000)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF5B4DFF)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadingLinks
              ? const Center(child: CircularProgressIndicator())
              : _filteredLinks.isEmpty
              ? const Center(
                  child: Text(
                    'No event sponsors found',
                    style: TextStyle(color: Color(0xFF9E9E9E)),
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    itemCount: _filteredLinks.length,
                    itemBuilder: (context, index) {
                      final link = _filteredLinks[index];
                      final sponser = _sponserFor(link.sponserId);
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: (sponser == null || sponser.logoPath.isEmpty)
                                ? Container(
                                    color: Color(0xFFF1F1F5),
                                    child: const Icon(
                                      Icons.handshake_outlined,
                                      color: Color(0xFF9E9E9E),
                                      size: 20,
                                    ),
                                  )
                                : Image.network(
                                    SponserApiService.fullImageUrl(
                                      sponser.logoPath,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        Container(
                                          color: Color(0xFFF1F1F5),
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: Color(0xFF9E9E9E),
                                            size: 20,
                                          ),
                                        ),
                                  ),
                          ),
                        ),
                        title: Text(
                          sponser?.name ?? 'Sponsor #${link.sponserId}',
                          style: const TextStyle(color: Color(0xFF212121)),
                        ),
                        subtitle: Text(
                          'ID: ${link.id}  •  ${_eventNameFor(link.eventId)}',
                          style: const TextStyle(color: Color(0xFF9E9E9E)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Color(0xFF757575),
                              ),
                              onPressed: () => _startEditLink(link),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _confirmDeleteLink(link),
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
