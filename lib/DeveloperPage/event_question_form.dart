import 'package:flutter/material.dart';
import '../services/event_api_service.dart';
import '../services/event_question_api_service.dart';
import './SearchDialog/event_search_dialog.dart';

// EventQuestionTypeID values that require >=2 Options (must match
// OPTION_REQUIRED_TYPE_IDS in EventQuestion_Controllers.py):
//   2 = Checkbox, 3 = Radio box
const Set<int> _optionRequiredTypeIds = {2, 3};

class EventQuestionForm extends StatefulWidget {
  const EventQuestionForm({super.key});

  @override
  State<EventQuestionForm> createState() => EventQuestionFormState();
}

class EventQuestionFormState extends State<EventQuestionForm> {
  final _formKey = GlobalKey<FormState>();

  final _questionController = TextEditingController();
  final _sortOrderController = TextEditingController();

  List<EventModel> _events = [];
  int? _selectedEventId;
  bool _loadingEvents = false;

  List<EventQuestionTypeModel> _questionTypes = [];
  int? _selectedQuestionTypeId;
  bool _loadingQuestionTypes = false;

  bool _isRequire = false;

  // One controller per Option row, so the UI can grow/shrink freely.
  final List<TextEditingController> _optionControllers = [];

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingEventQuestionId;

  List<EventQuestionModel> _eventQuestions = [];
  bool _loadingEventQuestions = false;
  final _eventQuestionSearchController = TextEditingController();
  List<EventQuestionModel> _filteredEventQuestions = [];
  int? _filterEventId; // null = "All Events"

  bool get _optionsRequired =>
      _selectedQuestionTypeId != null &&
      _optionRequiredTypeIds.contains(_selectedQuestionTypeId);

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadQuestionTypes();
    _addOptionField();
    _addOptionField();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _sortOrderController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    _eventQuestionSearchController.dispose();
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

  Future<void> _loadQuestionTypes() async {
    setState(() => _loadingQuestionTypes = true);
    try {
      final types = await EventQuestionApiService.getAllEventQuestionTypes();
      if (!mounted) return;
      setState(() {
        _questionTypes = types;
        if (_selectedQuestionTypeId != null &&
            !_questionTypes.any((t) => t.id == _selectedQuestionTypeId)) {
          _selectedQuestionTypeId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load question types: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingQuestionTypes = false);
    }
  }

  Future<void> reloadQuestionTypes() => _loadQuestionTypes();

  Future<void> _loadEventQuestions() async {
    setState(() => _loadingEventQuestions = true);
    try {
      final data = _filterEventId == null
          ? await EventQuestionApiService.getAllEventQuestions()
          : await EventQuestionApiService.getEventQuestionsByEvent(
              _filterEventId!,
            );
      if (!mounted) return;
      setState(() {
        _eventQuestions = data;
        _filteredEventQuestions = data;
      });
      if (_eventQuestionSearchController.text.isNotEmpty) {
        _filterEventQuestions(_eventQuestionSearchController.text);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingEventQuestions = false);
    }
  }

  Future<void> _onEventFilterChanged(int? eventId) async {
    setState(() => _filterEventId = eventId);
    _eventQuestionSearchController.clear();
    await _loadEventQuestions();
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

  String _questionTypeNameFor(int typeId) {
    final match = _questionTypes.where((t) => t.id == typeId);
    return match.isNotEmpty ? match.first.name : 'Type #$typeId';
  }

  void _filterEventQuestions(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredEventQuestions = _eventQuestions.where((question) {
        return question.id.toString().contains(q) ||
            question.question.toLowerCase().contains(q) ||
            _eventNameFor(question.eventId).toLowerCase().contains(q);
      }).toList();
    });
  }

  void _addOptionField([String text = '']) {
    setState(() {
      _optionControllers.add(TextEditingController(text: text));
    });
  }

  void _removeOptionField(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
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
    _loadEventQuestions();
  }

  void _startEdit(EventQuestionModel q) {
    _questionController.text = q.question;
    _sortOrderController.text = q.sortOrder.toString();

    for (final c in _optionControllers) {
      c.dispose();
    }
    _optionControllers.clear();
    if (q.options != null && q.options!.isNotEmpty) {
      for (final opt in q.options!) {
        _optionControllers.add(TextEditingController(text: opt));
      }
    } else {
      _optionControllers.add(TextEditingController());
      _optionControllers.add(TextEditingController());
    }

    setState(() {
      _editingEventQuestionId = q.id;
      _selectedEventId = q.eventId;
      _selectedQuestionTypeId = q.questionTypeId;
      _isRequire = q.isRequire;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _questionController.clear();
    _sortOrderController.clear();

    for (final c in _optionControllers) {
      c.dispose();
    }
    _optionControllers.clear();
    _optionControllers.add(TextEditingController());
    _optionControllers.add(TextEditingController());

    setState(() {
      _editingEventQuestionId = null;
      _selectedEventId = null;
      _selectedQuestionTypeId = null;
      _isRequire = false;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteEventQuestion(EventQuestionModel q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete event question?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete "${q.question}".',
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
        await EventQuestionApiService.deleteEventQuestion(q.id);
        _loadEventQuestions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEventId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an event')));
      return;
    }
    if (_selectedQuestionTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a question type')),
      );
      return;
    }

    final sortOrder = int.tryParse(_sortOrderController.text.trim());
    if (sortOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sort Order must be a number')),
      );
      return;
    }

    List<String>? options;
    if (_optionsRequired) {
      options = _optionControllers
          .map((c) => c.text.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      if (options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Checkbox / Radio box questions need at least 2 Options',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      if (_editingEventQuestionId == null) {
        final result = await EventQuestionApiService.createEventQuestion(
          eventId: _selectedEventId!,
          question: _questionController.text.trim(),
          questionTypeId: _selectedQuestionTypeId!,
          isRequire: _isRequire,
          sortOrder: sortOrder,
          options: options,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg']?.toString() ?? 'Question created'),
          ),
        );
      } else {
        await EventQuestionApiService.updateEventQuestion(
          eventQuestionId: _editingEventQuestionId!,
          eventId: _selectedEventId!,
          question: _questionController.text.trim(),
          questionTypeId: _selectedQuestionTypeId!,
          isRequire: _isRequire,
          sortOrder: sortOrder,
          options: options,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Question updated')));
      }

      _startCreate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            if (_editingEventQuestionId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Event Question ID: $_editingEventQuestionId',
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
              controller: _questionController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Event Question'),
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        _questionTypes.any(
                          (t) => t.id == _selectedQuestionTypeId,
                        )
                        ? _selectedQuestionTypeId
                        : null,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration(
                      _loadingQuestionTypes
                          ? 'Loading question types...'
                          : 'Question Type',
                    ),
                    items: _questionTypes
                        .map(
                          (t) => DropdownMenuItem<int>(
                            value: t.id,
                            child: Text(t.name),
                          ),
                        )
                        .toList(),
                    onChanged: _loadingQuestionTypes
                        ? null
                        : (value) =>
                              setState(() => _selectedQuestionTypeId = value),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                IconButton(
                  onPressed: _loadingQuestionTypes ? null : _loadQuestionTypes,
                  icon: _loadingQuestionTypes
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh question types',
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _sortOrderController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Sort Order'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Colors.white,
              title: const Text(
                'Required',
                style: TextStyle(color: Colors.white70),
              ),
              value: _isRequire,
              onChanged: (v) => setState(() => _isRequire = v),
            ),

            if (_optionsRequired) ...[
              const SizedBox(height: 8),
              const Text(
                'Options (at least 2)',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              ..._optionControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration('Option ${index + 1}'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: _optionControllers.length > 2
                            ? () => _removeOptionField(index)
                            : null,
                        tooltip: 'Remove option',
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addOptionField(),
                  icon: const Icon(Icons.add, color: Colors.white70),
                  label: const Text(
                    'Add option',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

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
                    : Text(
                        _editingEventQuestionId == null
                            ? 'Create Question'
                            : 'Update Question',
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
                child: const Text('View / Manage Event Questions'),
              ),
            ),

            if (_editingEventQuestionId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Question'),
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
                onPressed: _loadEventQuestions,
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
            controller: _eventQuestionSearchController,
            onChanged: _filterEventQuestions,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID or question',
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
          child: _loadingEventQuestions
              ? const Center(child: CircularProgressIndicator())
              : _filteredEventQuestions.isEmpty
              ? const Center(
                  child: Text(
                    'No event questions found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredEventQuestions.length,
                  itemBuilder: (context, index) {
                    final q = _filteredEventQuestions[index];
                    return ListTile(
                      title: Text(
                        q.question,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'ID: ${q.id}  •  ${_eventNameFor(q.eventId)}  •  '
                        '${_questionTypeNameFor(q.questionTypeId)}  •  '
                        '${q.isRequire ? "Required" : "Optional"}  •  '
                        'Sort: ${q.sortOrder}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () => _startEdit(q),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDeleteEventQuestion(q),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}