import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ticket_com/services/attendee_response_api_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_question_api_service.dart';
import 'package:ticket_com/services/orders_api_service.dart';
import 'package:ticket_com/services/ticket_attendence_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';
import 'package:ticket_com/utils/file_download.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kGreen = Color(0xFF2E9E5B);

// Question type convention (matches checkout_page.dart / backend):
//   1 = Text, 2 = Checkbox, 3 = Radio, 4 = Encrypted text, 5 = Yes/No
const int _typeCheckbox = 2;
const int _typeRadio = 3;
const int _typeYesNo = 5;
const List<String> _yesNoOptions = ['Yes', 'No'];

/// Analytics & attendee export screen for a single event. Shows who joined
/// (attendees), their question answers, sales per ticket type and per-option
/// question breakdowns as bar charts, and lets the organizer export the data
/// as CSV or PDF.
class EventAnalyticsPage extends StatefulWidget {
  const EventAnalyticsPage({
    super.key,
    required this.event,
    required this.ticketTypes,
  });

  final EventModel event;
  final List<TicketTypeModel> ticketTypes;

  @override
  State<EventAnalyticsPage> createState() => _EventAnalyticsPageState();
}

class _AttendeeRow {
  _AttendeeRow({
    required this.attendee,
    required this.ticketType,
    required this.order,
    this.answers = const {},
  });

  final TicketAttendeeModel attendee;
  final TicketTypeModel ticketType;
  final OrderModel? order;
  final Map<int, List<String>> answers; // questionId -> formatted answer(s)

  String get fullName => '${attendee.firstName} ${attendee.lastName}'.trim();
}

class _OptionCount {
  const _OptionCount(this.label, this.count);

  final String label;
  final int count;
}

class _QuestionStat {
  _QuestionStat({
    required this.question,
    required this.options,
    required this.totalResponses,
    required this.sampleText,
  });

  final EventQuestionModel question;
  final List<_OptionCount> options;
  final int totalResponses;
  final List<String> sampleText;

  bool get hasOptions => options.isNotEmpty;
}

class _EventAnalyticsPageState extends State<EventAnalyticsPage> {
  bool _loading = true;
  String? _error;

  List<_AttendeeRow> _rows = [];
  Map<int, TicketTypeModel> _typeById = {};
  List<_QuestionStat> _questionStats = [];
  int _soldCount = 0;
  int _revenue = 0;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _typeById = {for (final t in widget.ticketTypes) t.id: t};
      final eventTypeIds =
          widget.ticketTypes.map((t) => t.id).toSet();

      // All fetches are full-list (backend has no per-event join), so filter
      // locally by the event's ticket type ids.
      final attendees = await TicketAttendenceApiService
          .getAllTicketAttendees();
      final orders = await OrdersApiService.getAllOrders();
      final questions = await EventQuestionApiService
          .getEventQuestionsByEvent(widget.event.id);
      final responses = await AttendeeResponseApiService
          .getAllAttendeeResponses();

      final eventAttendees = attendees
          .where((a) => eventTypeIds.contains(a.ticketTypeId))
          .toList();
      final attendeeIds = eventAttendees.map((a) => a.id).toSet();
      final orderById = {for (final o in orders) o.id: o};

      // Group responses by attendee id and by question id.
      final byAttendee = <int, List<AttendeeResponseModel>>{};
      for (final r in responses) {
        if (!attendeeIds.contains(r.attendeeId)) continue;
        byAttendee.putIfAbsent(r.attendeeId, () => []).add(r);
      }
      final questionById = {for (final q in questions) q.id: q};

      // Build per-attendee rows with formatted answers.
      final rows = <_AttendeeRow>[];
      for (final at in eventAttendees) {
        final ticket = _typeById[at.ticketTypeId];
        if (ticket == null) continue;
        final answers = <int, List<String>>{};
        for (final r in byAttendee[at.id] ?? const <AttendeeResponseModel>[]) {
          final q = questionById[r.eventQuestionId];
          if (q == null) continue;
          answers.putIfAbsent(q.id, () => []).add(_formatAnswer(q, r.attendeeAnswer));
        }
        rows.add(_AttendeeRow(
          attendee: at,
          ticketType: ticket,
          order: orderById[at.orderId],
          answers: answers,
        ));
      }
      rows.sort((a, b) => a.attendee.id.compareTo(b.attendee.id));

      // Question analytics.
      final stats = <_QuestionStat>[];
      for (final q in questions) {
        _ResponseAggregate agg;
        try {
          agg = _aggregate(q, byAttendee, attendeeIds);
        } catch (_) {
          continue;
        }
        stats.add(_QuestionStat(
          question: q,
          options: agg.options,
          totalResponses: agg.total,
          sampleText: agg.samples,
        ));
      }

      final sold = rows.length;
      var revenue = 0;
      for (final r in rows) {
        revenue += r.ticketType.priceInKip;
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _questionStats = stats;
        _soldCount = sold;
        _revenue = revenue;
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

  // ---------------- aggregation ----------------

  static _ResponseAggregate _aggregate(
    EventQuestionModel q,
    Map<int, List<AttendeeResponseModel>> byAttendee,
    Set<int> attendeeIds,
  ) {
    final options =
        q.questionTypeId == _typeYesNo ? _yesNoOptions : (q.options ?? const []);
    final counts = <String, int>{};
    final samples = <String>[];
    var responses = 0;

    for (final id in attendeeIds) {
      for (final r in byAttendee[id] ?? const <AttendeeResponseModel>[]) {
        if (r.eventQuestionId != q.id) continue;
        responses++;
        samples.add(r.attendeeAnswer.isEmpty ? '—' : r.attendeeAnswer);
        switch (q.questionTypeId) {
          case _typeCheckbox:
            for (final part in r.attendeeAnswer.split(',')) {
              final index = int.tryParse(part.trim());
              if (index == null) {
                counts[part.trim()] = (counts[part.trim()] ?? 0) + 1;
              } else {
                final label = (index >= 1 && index <= options.length)
                    ? options[index - 1]
                    : '$index';
                counts[label] = (counts[label] ?? 0) + 1;
              }
            }
          case _typeRadio:
          case _typeYesNo:
            final index = int.tryParse(r.attendeeAnswer.trim());
            if (index == null) {
              counts[r.attendeeAnswer.trim()] = (counts[r.attendeeAnswer.trim()] ?? 0) + 1;
            } else {
              final label = (index >= 1 && index <= options.length)
                  ? options[index - 1]
                  : '$index';
              counts[label] = (counts[label] ?? 0) + 1;
            }
          default:
            // text / encrypted: no per-option breakdown
            break;
        }
      }
    }

    final list = <_OptionCount>[];
    for (final entry in counts.entries) {
      list.add(_OptionCount(entry.key, entry.value));
    }
    list.sort((a, b) => b.count.compareTo(a.count));
    return _ResponseAggregate(list, responses, samples);
  }

  static String _formatAnswer(EventQuestionModel q, String answer) {
    final options =
        q.questionTypeId == _typeYesNo ? _yesNoOptions : (q.options ?? const []);
    switch (q.questionTypeId) {
      case _typeCheckbox:
        final indices = answer
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();
        if (indices.isEmpty || options.isEmpty) return answer;
        return indices
            .map((i) =>
                (i >= 1 && i <= options.length) ? options[i - 1] : '$i')
            .join(', ');
      case _typeRadio:
      case _typeYesNo:
        final index = int.tryParse(answer.trim());
        if (index != null && index >= 1 && index <= options.length) {
          return options[index - 1];
        }
        return answer;
      default:
        return answer;
    }
  }

  // ---------------- export ----------------

  String get _fileBase =>
      'event_${widget.event.id}_analytics_'
      '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

  String _csvContent() {
    final buf = StringBuffer();
    buf.writeln('Event,"${_csvSanitize(widget.event.name)}"');
    buf.writeln('Start,${_dateFmt(widget.event.start)}');
    buf.writeln('End,${_dateFmt(widget.event.end)}');
    buf.writeln('Total attendees,$_soldCount');
    buf.writeln('Revenue,$_revenue');
    buf.writeln();

    buf.writeln('=== TICKET TYPE SUMMARY ===');
    buf.writeln('Type,Price (KIP),Sold,Revenue (KIP)');
    final soldByType = <int, int>{};
    for (final r in _rows) {
      soldByType[r.ticketType.id] = (soldByType[r.ticketType.id] ?? 0) + 1;
    }
    for (final t in widget.ticketTypes) {
      final sold = soldByType[t.id] ?? 0;
      buf.writeln('${_csvSanitize(t.typeName)},${t.priceInKip},$sold,'
          '${t.priceInKip * sold}');
    }
    buf.writeln();

    buf.writeln('=== QUESTION SUMMARY ===');
    buf.writeln('Question,Answer option,Count');
    for (final stat in _questionStats) {
      if (stat.hasOptions) {
        for (final o in stat.options) {
          buf.writeln('${_csvSanitize(stat.question.question)},'
              '${_csvSanitize(o.label)},${o.count}');
        }
      } else {
        buf.writeln('${_csvSanitize(stat.question.question)},'
            '(text answers),${stat.totalResponses}');
      }
    }
    buf.writeln();

    buf.writeln('=== ATTENDEES ===');
    final headers = [
      'First name',
      'Last name',
      'Phone',
      'Email',
      'National ID',
      'Ticket type',
      'Price (KIP)',
      'Purchased at',
      for (final stat in _questionStats) stat.question.question,
    ];
    buf.writeln(headers.map(_csvSanitize).join(','));
    for (final r in _rows) {
      final row = <String>[
        r.attendee.firstName,
        r.attendee.lastName,
        r.attendee.phoneNum,
        r.attendee.email,
        r.attendee.nationalId ?? '',
        r.ticketType.typeName,
        '${r.ticketType.priceInKip}',
        r.order?.paymentDate == null ? '' : _dateFmt(r.order!.paymentDate!),
        for (final stat in _questionStats)
          (r.answers[stat.question.id] ?? const []).join(' / '),
      ];
      buf.writeln(row.map(_csvSanitize).join(','));
    }
    return buf.toString();
  }

  static String _csvSanitize(String value) =>
      '"${value.replaceAll('"', '""')}"';

  static String _dateFmt(DateTime d) =>
      DateFormat('yyyy-MM-dd HH:mm').format(d);

  static String _formatKip(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final remaining = s.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buf.write(',');
    }
    return '$buf KIP';
  }

  Future<void> _exportCsv() async {
    await _runExport('csv', () async {
      return Uint8List.fromList(utf8.encode(_csvContent()));
    });
  }

  Future<void> _exportPdf() async {
    await _runExport('pdf', _buildPdfBytes);
  }

  Future<void> _runExport(
    String kind,
    Future<Uint8List> Function() buildBytes,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (kIsWeb) {
        final bytes = await buildBytes();
        downloadBytes(
          fileName: '$_fileBase.$kind',
          mimeType: kind == 'csv' ? 'text/csv' : 'application/pdf',
          bytes: bytes,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$_fileBase.$kind');
        await file.writeAsBytes(await buildBytes());
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(file.path, mimeType: kind == 'csv' ? 'text/csv' : 'application/pdf'),
            ],
            fileNameOverrides: [file.uri.pathSegments.last],
            title: 'Event analytics',
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Uint8List> _buildPdfBytes() async {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );
    final soldByType = <int, int>{};
    for (final r in _rows) {
      soldByType[r.ticketType.id] = (soldByType[r.ticketType.id] ?? 0) + 1;
    }

    final ticketRows = <List<String>>[
      for (final t in widget.ticketTypes)
        [
          t.typeName,
          '${t.priceInKip}',
          '${soldByType[t.id] ?? 0}',
          '${t.priceInKip * (soldByType[t.id] ?? 0)}',
        ],
    ];

    final questionRows = <List<String>>[
      for (final stat in _questionStats)
        if (stat.hasOptions)
          for (final o in stat.options)
            [stat.question.question, o.label, '${o.count}']
        else
          [stat.question.question, '(text answers)', '${stat.totalResponses}'],
    ];

    final attendeeHeaders = <String>[
      'Name',
      'Phone',
      'Email',
      'Ticket',
      'Purchased',
      for (final stat in _questionStats) stat.question.question,
    ];
    final attendeeRows = <List<String>>[
      for (final r in _rows)
        [
          r.fullName,
          r.attendee.phoneNum,
          r.attendee.email,
          r.ticketType.typeName,
          r.order?.paymentDate == null ? '' : _dateFmt(r.order!.paymentDate!),
          for (final stat in _questionStats)
            (r.answers[stat.question.id] ?? const []).join(' / '),
        ],
    ];

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              widget.event.name,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(_kTextDark.toARGB32()),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${_dateFmt(widget.event.start)}  \u2192  ${_dateFmt(widget.event.end)}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: const ['Total attendees', 'Revenue (KIP)'],
              data: [
                ['$_soldCount', '$_revenue'],
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(_kAccentARGB)),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Ticket types', style: _pdfHeading),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const ['Type', 'Price', 'Sold', 'Revenue'],
              data: ticketRows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellPadding: const pw.EdgeInsets.all(5),
            ),
            if (questionRows.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Question summary', style: _pdfHeading),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: const ['Question', 'Option', 'Count'],
                data: questionRows,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(5),
              ),
            ],
            if (attendeeRows.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Attendees', style: _pdfHeading),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: attendeeHeaders,
                data: attendeeRows,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.all(4),
              ),
            ],
          ],
        ),
      ),
    );
    return doc.save();
  }

  pw.TextStyle get _pdfHeading => pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromInt(_kAccentARGB),
      );

  static const int _kAccentARGB = 0xFF5B4DFF;

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Analytics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              widget.event.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _kTextGrey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed: _exporting ? null : _exportCsv,
            icon: const Icon(Icons.table_view_outlined),
          ),
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _exporting ? null : _exportPdf,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _error != null
              ? _errorBox()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _summaryCards(),
                    const SizedBox(height: 20),
                    _ticketsChart(),
                    const SizedBox(height: 20),
                    _questionsSection(),
                    const SizedBox(height: 20),
                    _attendeesSection(),
                  ],
                ),
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.groups_outlined,
            value: '$_soldCount',
            label: 'Tickets sold',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.payments_outlined,
            value: _formatKip(_revenue),
            label: 'Revenue',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.confirmation_number_outlined,
            value: '${widget.ticketTypes.length}',
            label: 'Ticket types',
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kAccent, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
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
            label,
            style: const TextStyle(color: _kTextGrey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _ticketsChart() {
    final soldByType = <int, int>{};
    for (final r in _rows) {
      soldByType[r.ticketType.id] = (soldByType[r.ticketType.id] ?? 0) + 1;
    }
    final maxSold =
        widget.ticketTypes.isEmpty ? 0 : (soldByType.values.isEmpty ? 0 : soldByType.values.reduce((a, b) => a > b ? a : b));
    return _card(
      title: 'Tickets sold by type',
      child: widget.ticketTypes.isEmpty
          ? const Text(
              'No ticket types configured.',
              style: TextStyle(color: _kTextGrey),
            )
          : Column(
              children: [
                for (var i = 0; i < widget.ticketTypes.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _hbarRow(
                    label: widget.ticketTypes[i].typeName,
                    value: '${soldByType[widget.ticketTypes[i].id] ?? 0} sold',
                    count: soldByType[widget.ticketTypes[i].id] ?? 0,
                    max: maxSold,
                    color: kAccent,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _hbarRow({
    required String label,
    required String value,
    required int count,
    required int max,
    required Color color,
  }) {
    final fraction =
        max <= 0 ? 0.0 : (count / max).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(color: const Color(0xFFEFEEFC)),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      heightFactor: 1,
                      child: Container(color: color),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _questionsSection() {
    return _card(
      title: 'Question answers',
      child: _questionStats.isEmpty
          ? const Text(
              'This event has no questions.',
              style: TextStyle(color: _kTextGrey),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _questionStats.length; i++) ...[
                  if (i > 0) const Divider(color: Color(0xFFE0DCFD), height: 24),
                  _questionCard(_questionStats[i]),
                ],
              ],
            ),
    );
  }

  Widget _questionCard(_QuestionStat stat) {
    final total =
        stat.hasOptions ? stat.options.fold<int>(0, (s, o) => s + o.count) : stat.totalResponses;
    final max =
        stat.hasOptions ? (stat.options.isEmpty ? 0 : stat.options.first.count) : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.question.question,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$total response${total == 1 ? '' : 's'}',
          style: const TextStyle(color: _kTextGrey, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (stat.hasOptions)
          Column(
            children: [
              for (var i = 0; i < stat.options.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _hbarRow(
                  label: stat.options[i].label,
                  value: '${stat.options[i].count} '
                      '(${total == 0 ? 0 : (stat.options[i].count * 100 / total).round()}%)',
                  count: stat.options[i].count,
                  max: max,
                  color: i.isEven ? kAccent : const Color(0xFF8E2DE2),
                ),
              ],
            ],
          )
        else ...[
          if (stat.sampleText.isEmpty)
            const Text('No answers yet.',
                style: TextStyle(color: _kTextGrey, fontSize: 12))
          else
            for (final t in stat.sampleText.take(20))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $t',
                  style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
                ),
              ),
        ],
      ],
    );
  }

  Widget _attendeesSection() {
    return _card(
      title: 'People who joined (${_rows.length})',
      child: _rows.isEmpty
          ? const Text(
              'No one has bought a ticket yet.',
              style: TextStyle(color: _kTextGrey),
            )
          : Column(
              children: [
                for (var i = 0; i < _rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _attendeeCard(_rows[i]),
                ],
              ],
            ),
    );
  }

  Widget _attendeeCard(_AttendeeRow row) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0DCFD), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  row.fullName.isEmpty ? '?' : row.fullName.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: kAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.attendee.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _kTextGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  row.ticketType.typeName,
                  style: const TextStyle(
                    color: _kGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Phone: ${row.attendee.phoneNum}   •   '
            '${row.order?.paymentDate == null ? 'purchase date unknown' : 'Purchased: ${_dateFmt(row.order!.paymentDate!)}'}',
            style: const TextStyle(color: _kTextGrey, fontSize: 12),
          ),
          if ((row.attendee.nationalId ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'National ID: ${row.attendee.nationalId}',
              style: const TextStyle(color: _kTextGrey, fontSize: 12),
            ),
          ],
          if (row.answers.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFE0DCFD), height: 1),
            const SizedBox(height: 8),
            for (final entry in row.answers.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _AnswerLine(
                  question: _questionTextFor(entry.key),
                  answer: entry.value.join(' / '),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _questionTextFor(int questionId) {
    for (final stat in _questionStats) {
      if (stat.question.id == questionId) return stat.question.question;
    }
    return 'Question #$questionId';
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
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
}

class _ResponseAggregate {
  const _ResponseAggregate(this.options, this.total, this.samples);

  final List<_OptionCount> options;
  final int total;
  final List<String> samples;
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.chat_bubble_outline, color: kAccent, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: _kTextDark, fontSize: 12.5, height: 1.4),
              children: [
                TextSpan(
                  text: '$question: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: answer),
              ],
            ),
          ),
        ),
      ],
    );
  }
}