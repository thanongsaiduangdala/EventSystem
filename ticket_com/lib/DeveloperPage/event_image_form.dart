import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/event_api_service.dart';
import '../services/event_image_api_service.dart';
import './SearchDialog/event_search_dialog.dart';

class EventImageForm extends StatefulWidget {
  const EventImageForm({super.key});

  @override
  State<EventImageForm> createState() => EventImageFormState();
}

class EventImageFormState extends State<EventImageForm> {
  final _formKey = GlobalKey<FormState>();

  final _imageNameController = TextEditingController();
  final _picker = ImagePicker();

  // A newly picked local file (create, or replace-during-edit).
  // A newly picked image, held as bytes (works on web + mobile + desktop --
  // dart:io File isn't available on Flutter Web).
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  // The path already stored on the server, shown as a preview while editing
  // if the user hasn't picked a replacement.
  String? _existingImagePath;

  List<EventModel> _events = [];
  int? _selectedEventId;
  bool _loadingEvents = false;

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingImageId;

  // Whether this image should become (or remain) the one thumbnail for its
  // event. Applied as a separate call after create/replace/update succeeds.
  bool _setAsThumbnail = false;

  List<EventImageModel> _eventImages = [];
  bool _loadingEventImages = false;
  final _eventImageSearchController = TextEditingController();
  List<EventImageModel> _filteredEventImages = [];
  int? _filterEventId; // null = "All Events"

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _imageNameController.dispose();
    _eventImageSearchController.dispose();
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

  // Backend only supports fetching every image (there's no "images for
  // event X" endpoint), so we always pull the full list and filter it
  // locally by event and/or search text.
  Future<void> _loadEventImages() async {
    setState(() => _loadingEventImages = true);
    try {
      final data = await EventImageApiService.getAllEventImages();
      if (!mounted) return;
      setState(() {
        _eventImages = data;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingEventImages = false);
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

  void _applyFilters() {
    final q = _eventImageSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredEventImages = _eventImages.where((image) {
        final matchesEvent =
            _filterEventId == null || image.eventId == _filterEventId;
        final matchesQuery =
            q.isEmpty ||
            image.id.toString().contains(q) ||
            image.imageName.toLowerCase().contains(q) ||
            _eventNameFor(image.eventId).toLowerCase().contains(q);
        return matchesEvent && matchesQuery;
      }).toList();
    });
  }

  void _filterEventImages(String query) {
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

  void _openTable() {
    setState(() => _showingTable = true);
    _loadEventImages();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = picked.name;
      });
    }
  }

  void _startEdit(EventImageModel img) {
    _imageNameController.text = img.imageName;

    setState(() {
      _editingImageId = img.id;
      _selectedEventId = img.eventId;
      _existingImagePath = img.imagePath;
      _pickedImageBytes = null;
      _pickedImageName = null;
      _showingTable = false;
      _setAsThumbnail = img.isThumbnail;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _imageNameController.clear();

    setState(() {
      _editingImageId = null;
      _selectedEventId = null;
      _existingImagePath = null;
      _pickedImageBytes = null;
      _pickedImageName = null;
      _showingTable = false;
      _setAsThumbnail = false;
    });
  }

  Future<void> _confirmDeleteEventImage(EventImageModel img) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete event image?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete "${img.imageName}".',
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
        await EventImageApiService.deleteEventImage(img.id);
        _loadEventImages();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleThumbnail(EventImageModel img) async {
    if (img.isThumbnail) return; // already the thumbnail, nothing to do
    try {
      await EventImageApiService.setThumbnail(img.id);
      _loadEventImages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEventId == null) {
      _snack('Please select an event');
      return;
    }

    final name = _imageNameController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      int resultImageId;

      if (_editingImageId == null) {
        // Create: a file is mandatory, there's nothing to point ImagePath at otherwise.
        if (_pickedImageBytes == null) {
          _snack('Please pick an image to upload');
          return;
        }
        final result = await EventImageApiService.uploadEventImage(
          eventId: _selectedEventId!,
          bytes: _pickedImageBytes!,
          filename: _pickedImageName ?? 'image.jpg',
          imageName: name.isEmpty ? null : name,
        );
        resultImageId = result['Image_ID'] as int;
        _snack(result['msg']?.toString() ?? 'Image uploaded');
      } else if (_pickedImageBytes != null) {
        // Edit + picked a replacement file: swap the file on the server.
        final result = await EventImageApiService.replaceEventImage(
          imageId: _editingImageId!,
          bytes: _pickedImageBytes!,
          filename: _pickedImageName ?? 'image.jpg',
          imageName: name.isEmpty ? null : name,
        );
        resultImageId = _editingImageId!;
        _snack(result['msg']?.toString() ?? 'Image replaced');
      } else {
        // Edit, no new file picked: just rename, keep the existing path.
        await EventImageApiService.updateEventImage(
          imageId: _editingImageId!,
          eventId: _selectedEventId!,
          imageName: name,
          imagePath: _existingImagePath ?? '',
        );
        resultImageId = _editingImageId!;
        _snack('Image updated');
      }

      // Applying the thumbnail flag is a separate call: the backend clears it
      // off whichever image previously held it for this event, so checking
      // the box here is what makes the old thumbnail stop being one.
      if (_setAsThumbnail) {
        await EventImageApiService.setThumbnail(resultImageId);
      }

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
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white),
      ),
    );
  }

  Widget _buildImagePreview() {
    Widget child;
    if (_pickedImageBytes != null) {
      child = Image.memory(_pickedImageBytes!, fit: BoxFit.cover);
    } else if (_existingImagePath != null) {
      child = Image.network(
        EventImageApiService.fullImageUrl(_existingImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white38),
        ),
      );
    } else {
      child = const Center(
        child: Icon(Icons.image_outlined, color: Colors.white38, size: 40),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 160,
        width: double.infinity,
        color: const Color(0xFF1E1E1E),
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
            if (_editingImageId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Event Image ID: $_editingImageId',
                  style: const TextStyle(
                    color: Colors.amber,
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
                        style: const TextStyle(color: Colors.white),
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
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh event list',
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _imageNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Image Name (optional)'),
            ),
            const SizedBox(height: 16),

            const Text('Image', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            _buildImagePreview(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
              label: Text(
                _pickedImageBytes == null && _existingImagePath == null
                    ? 'Choose Image'
                    : 'Choose Different Image',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
            ),

            const SizedBox(height: 8),

            CheckboxListTile(
              value: _setAsThumbnail,
              onChanged: (value) =>
                  setState(() => _setAsThumbnail = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.white,
              checkColor: Colors.black,
              title: const Text(
                'Set as event thumbnail',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Replaces whichever image is currently the thumbnail for this event',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),

            const SizedBox(height: 8),

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
                        _editingImageId == null
                            ? 'Create Image'
                            : 'Update Image',
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
                child: const Text('View / Manage Event Images'),
              ),
            ),

            if (_editingImageId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Image'),
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
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_filterEventId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  tooltip: 'Clear event filter',
                  onPressed: () => _onEventFilterChanged(null),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadEventImages,
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
            controller: _eventImageSearchController,
            onChanged: _filterEventImages,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID or image name',
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
          child: _loadingEventImages
              ? const Center(child: CircularProgressIndicator())
              : _filteredEventImages.isEmpty
              ? const Center(
                  child: Text(
                    'No event images found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    itemCount: _filteredEventImages.length,
                    itemBuilder: (context, index) {
                      final img = _filteredEventImages[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Image.network(
                              EventImageApiService.fullImageUrl(img.imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
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
                          img.imageName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'ID: ${img.id}  •  ${_eventNameFor(img.eventId)}'
                          '${img.isThumbnail ? '  •  ★ Thumbnail' : ''}  •  '
                          '${img.imagePath}',
                          style: TextStyle(
                            color: img.isThumbnail
                                ? Colors.amber
                                : Colors.white54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                img.isThumbnail ? Icons.star : Icons.star_border,
                                color: img.isThumbnail
                                    ? Colors.amber
                                    : Colors.white70,
                              ),
                              tooltip: img.isThumbnail
                                  ? 'This is the event thumbnail'
                                  : 'Set as event thumbnail',
                              onPressed: () => _toggleThumbnail(img),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white70),
                              onPressed: () => _startEdit(img),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _confirmDeleteEventImage(img),
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