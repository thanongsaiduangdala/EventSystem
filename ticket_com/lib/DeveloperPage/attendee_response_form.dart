import 'package:flutter/material.dart';
import '../services/attendee_response_api_service.dart';
import '../services/event_question_api_service.dart';
import '../services/ticket_attendence_api_service.dart';

// EventQuestionTypeID convention (matches eventquestiontype table):
//   1 = Text
//   2 = Checkbox   (multi-select, options come from EventQuestion.options)
//   3 = Radio box  (single-select, options come from EventQuestion.options)
//   4 = Text save as encrypted (plain text input; backend handles encryption)
//   5 = Yes or No  (single-select, fixed two-option list, no DB options)
//
// attendeeAnswer is always stored as plain text. For choice-type questions
// (2, 3, 5) it stores the 1-based index into the option list, comma-
// separated for checkboxes (e.g. "1,3"). This mirrors the existing data in
// attendeeresponse, where radio-box answers are stored as a single 1-based
// index string.
const int _typeText = 1;
const int _typeCheckbox = 2;
const int _typeRadio = 3;
const int _typeEncryptedText = 4;
const int _typeYesNo = 5;

const List<String> _yesNoOptions = ['Yes', 'No'];

class AttendeeResponseForm extends StatefulWidget {
  const AttendeeResponseForm({super.key});

  @override
  State<AttendeeResponseForm> createState() => AttendeeResponseFormState();
}

class AttendeeResponseFormState extends State<AttendeeResponseForm> {
  final _formKey = GlobalKey<FormState>();

  final _answerController = TextEditingController();

  List<EventQuestionModel> _eventQuestions = [];
  int? _selectedEventQuestionId;
  bool _loadingEventQuestions = false;

  List<TicketAttendeeModel> _attendees = [];
  int? _selectedAttendeeId;
  bool _loadingAttendees = false;

  // Answer state for choice-type questions.
  final Set<int> _selectedCheckboxIndices = {}; // 1-based option indices
  int? _selectedRadioIndex; // 1-based option index

  bool _isSubmitting = false;

  bool _showingTable = false;
  int? _editingResponseId;

  List<AttendeeResponseModel> _responses = [];
  bool _loadingResponses = false;
  final _responseSearchController = TextEditingController();
  List<AttendeeResponseModel> _filteredResponses = [];
  int? _filterAttendeeId; // null = "All Attendees"

  @override
  void initState() {
    super.initState();
    _loadEventQuestions();
    _loadAttendees();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _responseSearchController.dispose();
    super.dispose();
  }

  // ---------------- loading ----------------

  Future<void> _loadEventQuestions() async {
    setState(() => _loadingEventQuestions = true);
    try {
      final questions = await EventQuestionApiService.getAllEventQuestions();
      if (!mounted) return;
      setState(() {
        _eventQuestions = questions;
        if (_selectedEventQuestionId != null &&
            !_eventQuestions.any((q) => q.id == _selectedEventQuestionId)) {
          _selectedEventQuestionId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load event questions: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingEventQuestions = false);
    }
  }

  Future<void> reloadEventQuestions() => _loadEventQuestions();

  Future<void> _loadAttendees() async {
    setState(() => _loadingAttendees = true);
    try {
      final attendees =
          await TicketAttendenceApiService.getAllTicketAttendees();
      if (!mounted) return;
      setState(() {
        _attendees = attendees;
        if (_selectedAttendeeId != null &&
            !_attendees.any((a) => a.id == _selectedAttendeeId)) {
          _selectedAttendeeId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load attendees: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAttendees = false);
    }
  }

  Future<void> reloadAttendees() => _loadAttendees();

  Future<void> _loadResponses() async {
    setState(() => _loadingResponses = true);
    try {
      final data = _filterAttendeeId == null
          ? await AttendeeResponseApiService.getAllAttendeeResponses()
          : await AttendeeResponseApiService.getResponsesByAttendee(
              _filterAttendeeId!,
            );
      if (!mounted) return;
      setState(() {
        _responses = data;
        _filteredResponses = data;
      });
      if (_responseSearchController.text.isNotEmpty) {
        _filterResponses(_responseSearchController.text);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingResponses = false);
    }
  }

  Future<void> _onAttendeeFilterChanged(int? attendeeId) async {
    setState(() => _filterAttendeeId = attendeeId);
    _responseSearchController.clear();
    await _loadResponses();
  }

  // ---------------- helpers ----------------

  EventQuestionModel? _questionById(int? id) {
    if (id == null) return null;
    final match = _eventQuestions.where((q) => q.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  /// The option list to show for the currently selected question --
  /// whatever's stored on the question for Checkbox/Radio, or the fixed
  /// Yes/No pair for type 5 (which has no DB-backed options).
  List<String> _optionsFor(EventQuestionModel? question) {
    if (question == null) return const [];
    if (question.questionTypeId == _typeYesNo) return _yesNoOptions;
    return question.options ?? const [];
  }

  String _questionLabelFor(int eventQuestionId) {
    final match = _eventQuestions.where((q) => q.id == eventQuestionId);
    return match.isNotEmpty
        ? match.first.question
        : 'Question #$eventQuestionId';
  }

  String _attendeeLabelFor(int attendeeId) {
    final match = _attendees.where((a) => a.id == attendeeId);
    return match.isNotEmpty
        ? '${match.first.firstName} ${match.first.lastName}'
        : 'Attendee #$attendeeId';
  }

  /// Human-readable version of a stored answer, resolving choice-type
  /// indices back into their option text wherever possible.
  String _answerDisplayFor(AttendeeResponseModel r) {
    final question = _questionById(r.eventQuestionId);
    if (question == null) return r.attendeeAnswer;

    final options = _optionsFor(question);
    if (options.isEmpty) return r.attendeeAnswer;

    switch (question.questionTypeId) {
      case _typeCheckbox:
        final indices = r.attendeeAnswer
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>();
        final labels = indices
            .where((i) => i >= 1 && i <= options.length)
            .map((i) => options[i - 1]);
        return labels.isEmpty ? r.attendeeAnswer : labels.join(', ');
      case _typeRadio:
      case _typeYesNo:
        final i = int.tryParse(r.attendeeAnswer.trim());
        if (i != null && i >= 1 && i <= options.length) return options[i - 1];
        return r.attendeeAnswer;
      default:
        return r.attendeeAnswer;
    }
  }

  void _filterResponses(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredResponses = _responses.where((response) {
        return response.id.toString().contains(q) ||
            response.attendeeAnswer.toLowerCase().contains(q) ||
            _answerDisplayFor(response).toLowerCase().contains(q) ||
            _questionLabelFor(response.eventQuestionId)
                .toLowerCase()
                .contains(q) ||
            _attendeeLabelFor(response.attendeeId).toLowerCase().contains(q);
      }).toList();
    });
  }

  void _resetAnswerState() {
    _answerController.clear();
    _selectedCheckboxIndices.clear();
    _selectedRadioIndex = null;
  }

  /// Parses a stored attendeeAnswer string into whichever answer-state
  /// field matches the question's type, so editing an existing response
  /// pre-selects the right checkboxes/radio option/text.
  void _loadAnswerIntoState(EventQuestionModel? question, String answer) {
    _resetAnswerState();
    if (question == null) {
      _answerController.text = answer;
      return;
    }
    switch (question.questionTypeId) {
      case _typeCheckbox:
        for (final part in answer.split(',')) {
          final i = int.tryParse(part.trim());
          if (i != null) _selectedCheckboxIndices.add(i);
        }
        break;
      case _typeRadio:
      case _typeYesNo:
        _selectedRadioIndex = int.tryParse(answer.trim());
        break;
      default:
        _answerController.text = answer;
    }
  }

  /// Builds the final attendeeAnswer string to send to the backend from
  /// whichever answer-state field is active for the current question type.
  /// Returns null (with a snackbar shown) if the answer is incomplete.
  String? _buildAnswerOrShowError(EventQuestionModel question) {
    switch (question.questionTypeId) {
      case _typeCheckbox:
        if (_selectedCheckboxIndices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select at least one option')),
          );
          return null;
        }
        final sorted = _selectedCheckboxIndices.toList()..sort();
        return sorted.join(',');
      case _typeRadio:
      case _typeYesNo:
        if (_selectedRadioIndex == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select an option')),
          );
          return null;
        }
        return _selectedRadioIndex.toString();
      default:
        final text = _answerController.text.trim();
        if (text.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Answer is required')));
          return null;
        }
        return text;
    }
  }

  Future<void> _openEventQuestionPicker() async {
    final result = await showDialog<EventQuestionModel>(
      context: context,
      builder: (context) =>
          _EventQuestionPickerDialog(eventQuestions: _eventQuestions),
    );
    if (result != null) {
      setState(() {
        _selectedEventQuestionId = result.id;
        _resetAnswerState();
      });
    }
  }

  Future<void> _openAttendeePicker() async {
    final result = await showDialog<TicketAttendeeModel>(
      context: context,
      builder: (context) => _AttendeePickerDialog(attendees: _attendees),
    );
    if (result != null) {
      setState(() => _selectedAttendeeId = result.id);
    }
  }

  Future<void> _openAttendeeFilterPicker() async {
    final result = await showDialog<TicketAttendeeModel>(
      context: context,
      builder: (context) => _AttendeePickerDialog(
        attendees: _attendees,
        allowClear: true,
      ),
    );
    if (result != null) {
      await _onAttendeeFilterChanged(result.id == -1 ? null : result.id);
    }
  }

  void _openTable() {
    setState(() => _showingTable = true);
    _loadResponses();
  }

  void _startEdit(AttendeeResponseModel r) {
    final question = _questionById(r.eventQuestionId);
    _loadAnswerIntoState(question, r.attendeeAnswer);

    setState(() {
      _editingResponseId = r.id;
      _selectedEventQuestionId = r.eventQuestionId;
      _selectedAttendeeId = r.attendeeId;
      _showingTable = false;
    });
  }

  void _startCreate() {
    _formKey.currentState?.reset();
    _resetAnswerState();

    setState(() {
      _editingResponseId = null;
      _selectedEventQuestionId = null;
      _selectedAttendeeId = null;
      _showingTable = false;
    });
  }

  Future<void> _confirmDeleteResponse(AttendeeResponseModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete attendee response?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete "${_answerDisplayFor(r)}".',
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
        await AttendeeResponseApiService.deleteAttendeeResponse(r.id);
        _loadResponses();
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

    if (_selectedEventQuestionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event question')),
      );
      return;
    }
    if (_selectedAttendeeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an attendee')));
      return;
    }

    final question = _questionById(_selectedEventQuestionId);
    if (question == null) return;

    final answer = _buildAnswerOrShowError(question);
    if (answer == null) return;

    setState(() => _isSubmitting = true);

    try {
      if (_editingResponseId == null) {
        final result = await AttendeeResponseApiService.createAttendeeResponse(
          eventQuestionId: _selectedEventQuestionId!,
          attendeeId: _selectedAttendeeId!,
          attendeeAnswer: answer,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg']?.toString() ?? 'Response created'),
          ),
        );
      } else {
        await AttendeeResponseApiService.updateAttendeeResponse(
          responseId: _editingResponseId!,
          eventQuestionId: _selectedEventQuestionId!,
          attendeeId: _selectedAttendeeId!,
          attendeeAnswer: answer,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Response updated')));
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

  // ---------------- answer widget ----------------

  Widget _buildAnswerField() {
    final question = _questionById(_selectedEventQuestionId);

    if (question == null) {
      return TextFormField(
        enabled: false,
        style: const TextStyle(color: Colors.white38),
        decoration: _decoration('Select a question first'),
      );
    }

    switch (question.questionTypeId) {
      case _typeCheckbox:
        return _buildCheckboxAnswer(question);
      case _typeRadio:
        return _buildRadioAnswer(question, 'Answer');
      case _typeYesNo:
        return _buildRadioAnswer(question, 'Answer');
      case _typeEncryptedText:
        return TextFormField(
          controller: _answerController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: _decoration('Answer (stored encrypted)'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      case _typeText:
      default:
        return TextFormField(
          controller: _answerController,
          style: const TextStyle(color: Colors.white),
          decoration: _decoration('Answer'),
          maxLines: 2,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
    }
  }

  Widget _buildCheckboxAnswer(EventQuestionModel question) {
    final options = _optionsFor(question);
    if (options.isEmpty) {
      return const Text(
        'This question has no options configured.',
        style: TextStyle(color: Colors.redAccent),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Answer (select one or more)',
            style: TextStyle(color: Colors.white70)),
        ...options.asMap().entries.map((entry) {
          final index = entry.key + 1; // 1-based
          final label = entry.value;
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            checkColor: Colors.black,
            activeColor: Colors.white,
            title: Text(label, style: const TextStyle(color: Colors.white)),
            value: _selectedCheckboxIndices.contains(index),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedCheckboxIndices.add(index);
                } else {
                  _selectedCheckboxIndices.remove(index);
                }
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildRadioAnswer(EventQuestionModel question, String label) {
    final options = _optionsFor(question);
    if (options.isEmpty) {
      return const Text(
        'This question has no options configured.',
        style: TextStyle(color: Colors.redAccent),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        ...options.asMap().entries.map((entry) {
          final index = entry.key + 1; // 1-based
          final optionLabel = entry.value;
          return RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.white,
            title: Text(
              optionLabel,
              style: const TextStyle(color: Colors.white),
            ),
            value: index,
            groupValue: _selectedRadioIndex,
            onChanged: (value) => setState(() => _selectedRadioIndex = value),
          );
        }),
      ],
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
            if (_editingResponseId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Editing Response ID: $_editingResponseId',
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
                    onTap: _loadingEventQuestions
                        ? null
                        : _openEventQuestionPicker,
                    child: InputDecorator(
                      decoration: _decoration('Event Question'),
                      child: Text(
                        _selectedEventQuestionId == null
                            ? (_loadingEventQuestions
                                  ? 'Loading...'
                                  : 'Tap to search event question')
                            : _questionLabelFor(_selectedEventQuestionId!),
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _loadingEventQuestions ? null : _loadEventQuestions,
                  icon: _loadingEventQuestions
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh event questions',
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loadingAttendees ? null : _openAttendeePicker,
                    child: InputDecorator(
                      decoration: _decoration('Attendee'),
                      child: Text(
                        _selectedAttendeeId == null
                            ? (_loadingAttendees
                                  ? 'Loading...'
                                  : 'Tap to search attendee')
                            : _attendeeLabelFor(_selectedAttendeeId!),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadingAttendees ? null : _loadAttendees,
                  icon: _loadingAttendees
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh attendees',
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildAnswerField(),
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
                        _editingResponseId == null
                            ? 'Create Response'
                            : 'Update Response',
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
                child: const Text('View / Manage Attendee Responses'),
              ),
            ),

            if (_editingResponseId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _startCreate,
                  child: const Text('Cancel Edit / Create New Response'),
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
                  onTap: _openAttendeeFilterPicker,
                  child: InputDecorator(
                    decoration: _decoration('Filter by Attendee'),
                    child: Text(
                      _filterAttendeeId == null
                          ? 'All Attendees -- tap to filter'
                          : _attendeeLabelFor(_filterAttendeeId!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_filterAttendeeId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  tooltip: 'Clear attendee filter',
                  onPressed: () => _onAttendeeFilterChanged(null),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadResponses,
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
            controller: _responseSearchController,
            onChanged: _filterResponses,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by ID or answer',
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
          child: _loadingResponses
              ? const Center(child: CircularProgressIndicator())
              : _filteredResponses.isEmpty
              ? const Center(
                  child: Text(
                    'No attendee responses found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredResponses.length,
                  itemBuilder: (context, index) {
                    final r = _filteredResponses[index];
                    return ListTile(
                      title: Text(
                        _answerDisplayFor(r),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'ID: ${r.id}  •  ${_attendeeLabelFor(r.attendeeId)}  •  '
                        '${_questionLabelFor(r.eventQuestionId)}',
                        style: const TextStyle(color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () => _startEdit(r),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDeleteResponse(r),
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

/// Searchable event-question picker, private to this file.
///
/// Matches on question text or ID.
class _EventQuestionPickerDialog extends StatefulWidget {
  final List<EventQuestionModel> eventQuestions;

  const _EventQuestionPickerDialog({required this.eventQuestions});

  @override
  State<_EventQuestionPickerDialog> createState() =>
      _EventQuestionPickerDialogState();
}

class _EventQuestionPickerDialogState
    extends State<_EventQuestionPickerDialog> {
  final _searchController = TextEditingController();
  late List<EventQuestionModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.eventQuestions;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.eventQuestions.where((question) {
        return q.isEmpty ||
            question.id.toString().contains(q) ||
            question.question.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: SizedBox(
        width: 420,
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
                  hintText: 'Search by question or ID',
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
              child: widget.eventQuestions.isEmpty
                  ? const Center(
                      child: Text(
                        'No event questions loaded',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No event questions found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final question in _filtered)
                          ListTile(
                            title: Text(
                              question.question,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Question #${question.id}  •  Event #${question.eventId}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () => Navigator.pop(context, question),
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

/// Searchable attendee picker, private to this file.
///
/// Matches on first name, last name, email, or ID. When [allowClear] is
/// true, shows an "All Attendees" option that pops with a sentinel id of
/// -1, mirroring the order picker's clear-filter convention.
class _AttendeePickerDialog extends StatefulWidget {
  final List<TicketAttendeeModel> attendees;
  final bool allowClear;

  const _AttendeePickerDialog({
    required this.attendees,
    this.allowClear = false,
  });

  @override
  State<_AttendeePickerDialog> createState() => _AttendeePickerDialogState();
}

class _AttendeePickerDialogState extends State<_AttendeePickerDialog> {
  final _searchController = TextEditingController();
  late List<TicketAttendeeModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.attendees;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.attendees.where((a) {
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
                  hintText: 'Search attendees by name, email, or ID',
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
                      child: Text(
                        'No attendees found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      children: [
                        if (widget.allowClear)
                          ListTile(
                            leading: const Icon(
                              Icons.clear,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'All Attendees',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              TicketAttendeeModel(
                                id: -1,
                                ticketTypeId: 0,
                                orderId: 0,
                                firstName: '',
                                lastName: '',
                                phoneNum: '',
                                email: '',
                              ),
                            ),
                          ),
                        for (final attendee in _filtered)
                          ListTile(
                            title: Text(
                              '${attendee.firstName} ${attendee.lastName}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Attendee #${attendee.id}  •  ${attendee.email}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () => Navigator.pop(context, attendee),
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
