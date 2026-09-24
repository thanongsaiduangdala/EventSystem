import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ticket_com/map/location_picker_page.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kLavender = Color(0xFFEFEEFC);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

/// Create or edit an [EventModel]. Visually mirrors [EventDetailPage] (hero
/// header, icon-tile info rows, "About" section, floating action bar) but
/// every value shown there is an editable field here. Returns `true` via
/// Navigator.pop when the event was saved so the caller can refresh its list.
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

  DateTime? _startDateTime;
  DateTime? _endDateTime;

  List<EventOrganizer> _organizers = [];
  bool _loadingOrganizers = true;
  int? _selectedOrganizerId;

  bool _onePerPerson = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.event != null;

  EventOrganizer? get _selectedOrganizer {
    final id = _selectedOrganizerId;
    if (id == null) return null;
    for (final o in _organizers) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    if (ev != null) {
      _nameController.text = ev.name;
      _addressController.text = ev.address;
      _descriptionController.text = ev.description;
      _latitudeController.text = ev.latitude.toString();
      _longitudeController.text = ev.longitude.toString();
      _startDateTime = ev.start;
      _endDateTime = ev.end;
      _selectedOrganizerId = ev.organizerId;
      _onePerPerson = ev.onePerPerson;
    } else {
      _selectedOrganizerId = widget.organizerId;
    }
    _loadOrganizers();
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

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatForApi(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}:00';

  String _formatForDisplay(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)}  '
      '${_two(dt.hour)}:${_two(dt.minute)}';

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_startDateTime);
    if (picked != null) setState(() => _startDateTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_endDateTime);
    if (picked != null) setState(() => _endDateTime = picked);
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _snack('Fill in the event name and description');
      return;
    }
    if (_startDateTime == null || _endDateTime == null) {
      _snack('Select both start and end date/time');
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
    try {
      if (_isEditing) {
        await EventApiService.updateEvent(
          eventId: widget.event!.id,
          eventName: _nameController.text.trim(),
          eventStartingYMDT: _formatForApi(_startDateTime!),
          eventEndingYMDT: _formatForApi(_endDateTime!),
          eventAddress: _addressController.text.trim(),
          latitude: double.parse(_latitudeController.text.trim()),
          longitude: double.parse(_longitudeController.text.trim()),
          eventDescription: _descriptionController.text.trim(),
          eventOrganizerID: _selectedOrganizerId!,
          onePerPerson: _onePerPerson,
        );
      } else {
        await EventApiService.createEvent(
          eventName: _nameController.text.trim(),
          eventStartingYMDT: _formatForApi(_startDateTime!),
          eventEndingYMDT: _formatForApi(_endDateTime!),
          eventAddress: _addressController.text.trim(),
          latitude: double.parse(_latitudeController.text.trim()),
          longitude: double.parse(_longitudeController.text.trim()),
          eventDescription: _descriptionController.text.trim(),
          eventOrganizerID: _selectedOrganizerId!,
          onePerPerson: _onePerPerson,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _snack('Save failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: const Icon(Icons.event, color: Colors.white24, size: 72),
          ),
          Positioned(
            top: topPad + 12,
            left: 8,
            child: Row(
              children: [
                _circleIconButton(
                  icon: Icons.arrow_back_ios_new,
                  onTap: () => Navigator.pop(context),
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
              onTap: () => _snack('Add a cover photo after saving the event'),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 100),
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
              value == null ? 'Select date & time' : _formatForDisplay(value),
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
