import 'package:flutter/material.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kSurface = Color(0xFFF5F6FA);
const Color _kGreen = Color(0xFF2E9E5B);
const Color _kAmber = Color(0xFFFB8C00);
const Color _kRed = Color(0xFFE53935);

/// Event Approvals tab: review events organizers have submitted (or edited)
/// and approve or deny them. Approving makes the event visible to everyone;
/// denying leaves it hidden. Shown as one tab of `EmployeeDashboardPage`.
class EventApprovalsTab extends StatefulWidget {
  const EventApprovalsTab({super.key});

  @override
  State<EventApprovalsTab> createState() => _EventApprovalsTabState();
}

class _EventApprovalsTabState extends State<EventApprovalsTab> {
  List<EventModel> _events = [];
  Map<int, String> _organizerNames = {};

  bool _loading = true;
  String? _error;

  int _filterStatusId = 0; // 0 = all, else an EventStatus id

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
      final results = await Future.wait([
        EventApiService.getAllEventsWithStatus(),
        EventApiService.getAllOrganizers(),
      ]);
      if (!mounted) return;
      final events = results[0] as List<EventModel>;
      final orgs = results[1] as List<EventOrganizer>;
      setState(() {
        _events = events;
        _organizerNames = {for (final o in orgs) o.id: o.name};
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

  int get _pendingCount =>
      _events.where((e) => e.eventStatusId == EventStatus.pending).length;

  int get _approvedCount =>
      _events.where((e) => e.eventStatusId == EventStatus.approved).length;

  int get _deniedCount =>
      _events.where((e) => e.eventStatusId == EventStatus.denied).length;

  List<EventModel> get _filtered {
    if (_filterStatusId == 0) return _events;
    return _events.where((e) => e.eventStatusId == _filterStatusId).toList();
  }

  String _organizerNameFor(int id) => _organizerNames[id] ?? 'Organizer #$id';

  String _fmt(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmReview(EventModel event, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          approve ? 'Approve event?' : 'Deny event?',
          style: const TextStyle(color: _kTextDark),
        ),
        content: Text(
          approve
              ? '"${event.name}" will become visible to everyone.'
              : '"${event.name}" will stay hidden from the public.',
          style: const TextStyle(color: _kTextGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              approve ? 'Approve' : 'Deny',
              style: TextStyle(
                color: approve ? _kGreen : Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await EventApiService.setEventStatus(
        eventId: event.id,
        eventStatusId: approve ? EventStatus.approved : EventStatus.denied,
      );
      _snack(approve ? 'Event approved' : 'Event denied');
      await _load();
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: const Text(
          'Event Approvals',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _kTextDark),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _error != null && _events.isEmpty
          ? _errorBox()
          : RefreshIndicator(
              color: kAccent,
              backgroundColor: Colors.white,
              onRefresh: _load,
              child: Column(
                children: [
                  _summaryCard(),
                  _filterBar(),
                  Expanded(
                    child: _filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No events found',
                                  style: TextStyle(color: _kTextGrey),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _eventCard(_filtered[index]),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(_pendingCount, 'Pending', _kAmber),
          _stat(_approvedCount, 'Approved', _kGreen),
          _stat(_deniedCount, 'Denied', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _stat(int count, String label, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _kTextGrey, fontSize: 12.5)),
      ],
    );
  }

  Widget _filterBar() {
    final chips = <(int, String)>[
      (0, 'All'),
      (EventStatus.pending, 'Pending'),
      (EventStatus.approved, 'Approved'),
      (EventStatus.denied, 'Denied'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final (id, label) = chips[index];
            final selected = _filterStatusId == id;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _filterStatusId = id),
              selectedColor: kAccent,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0x14000000)),
              labelStyle: TextStyle(
                color: selected ? Colors.white : _kTextDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              showCheckmark: false,
            );
          },
        ),
      ),
    );
  }

  Widget _eventCard(EventModel event) {
    final isPending = event.eventStatusId == EventStatus.pending;
    return Container(
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_outlined,
                  color: kAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
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
                      _organizerNameFor(event.organizerId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              _statusChip(event.eventStatusId),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.schedule, 'Starts', _fmt(event.start)),
          _infoRow(Icons.event_busy_outlined, 'Ends', _fmt(event.end)),
          _infoRow(Icons.place_outlined, 'Address', event.address),
          const SizedBox(height: 10),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirmReview(event, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmReview(event, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Color(0x33E53935)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Deny'),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: event.eventStatusId == EventStatus.approved
                    ? const Color(0x142E9E5B)
                    : const Color(0x14E53935),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    event.eventStatusId == EventStatus.approved
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 16,
                    color: event.eventStatusId == EventStatus.approved
                        ? _kGreen
                        : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    event.eventStatusId == EventStatus.approved
                        ? 'Approved -- visible to everyone'
                        : 'Denied -- hidden from the public',
                    style: TextStyle(
                      color: event.eventStatusId == EventStatus.approved
                          ? _kGreen
                          : Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kTextGrey, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kTextDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(int statusId) {
    final (label, color) = switch (statusId) {
      EventStatus.approved => ('Approved', _kGreen),
      EventStatus.denied => ('Denied', Colors.redAccent),
      _ => ('Pending', _kAmber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
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
