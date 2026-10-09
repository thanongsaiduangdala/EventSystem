import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ticket_com/DeveloperPage/deny_reason_dialog.dart';
import 'package:ticket_com/HomePage/event_detail_page.dart';
import 'package:ticket_com/models/category_models.dart';
import 'package:ticket_com/services/category_api_service.dart';
import 'package:ticket_com/services/api_errors.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/review_live_service.dart';
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
  const EventApprovalsTab({super.key, this.focusId});

  /// Event to open for review as soon as the list has loaded (from a
  /// notification).
  final int? focusId;

  @override
  State<EventApprovalsTab> createState() => _EventApprovalsTabState();
}

class _EventApprovalsTabState extends State<EventApprovalsTab> {
  List<EventModel> _events = [];
  Map<int, String> _organizerNames = {};
  Map<int, EventOrganizer> _organizers = {};
  List<CategoryModel> _categories = [];
  Map<int, List<int>> _eventCategories = {};

  bool _loading = true;
  String? _error;

  int _filterStatusId = 0;
  bool _focusHandled = false;

  // Live updates: another reviewer (or an organizer) changed something, so
  // this list refreshes by itself instead of waiting for a manual reload.
  final ReviewLiveService _live = ReviewLiveService();
  StreamSubscription<ReviewChange>? _liveSub;

  // Only the newest load may write its result, so a slow response can never
  // overwrite a fresher one when several live updates arrive back to back.
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _liveSub = _live.changes.listen((change) {
      if (change.isResync || change.isEvent) _load(silent: true);
    });
    _live.connect();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _live.dispose();
    super.dispose();
  }

  /// [silent] reloads in the background (no spinner, errors ignored) -- used
  /// for live updates and after an approve / deny.
  Future<void> _load({bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        EventApiService.getAllEventsWithStatus(),
        EventApiService.getAllOrganizers(includeUnapproved: true),
        _optional(CategoryApiService.getAllCategories, const <CategoryModel>[]),
        _optional(
          CategoryApiService.getAllEventCategories,
          const <EventCategoryModel>[],
        ),
      ]);
      if (!mounted || seq != _loadSeq) return;
      final events = results[0] as List<EventModel>;
      final orgs = results[1] as List<EventOrganizer>;
      final categories = results[2] as List<CategoryModel>;
      final eventCats = results[3] as List<EventCategoryModel>;
      final eventCategories = <int, List<int>>{};
      for (final ec in eventCats) {
        eventCategories.putIfAbsent(ec.eventId, () => []).add(ec.categoryId);
      }
      setState(() {
        _events = events;
        _organizerNames = {for (final o in orgs) o.id: o.name};
        _organizers = {for (final o in orgs) o.id: o};
        _categories = categories;
        _eventCategories = eventCategories;
        _loading = false;
      });
      final focusId = widget.focusId;
      if (focusId != null && !_focusHandled) {
        _focusHandled = true;
        for (final e in events) {
          if (e.id == focusId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openEventDetail(e);
            });
            break;
          }
        }
      }
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      // A failed background refresh keeps showing what we already have.
      if (silent && !_loading) return;
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
    // Drafts haven't been submitted for review, so they never show here.
    if (_filterStatusId == 0) {
      return _events.where((e) => e.eventStatusId != EventStatus.draft).toList();
    }
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

  /// Category / link lookups are nice-to-have: never fail the tab over them.
  static Future<T> _optional<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }

  List<CategoryModel> _categoriesFor(int eventId) {
    return [
      for (final id in (_eventCategories[eventId] ?? const <int>[]))
        for (final c in _categories)
          if (c.id == id) c,
    ];
  }

  /// Opens the same event page users see on the home screen, with the buy
  /// bar replaced by Approve / Deny. The choice still goes through the usual
  /// confirmation dialog.
  Future<void> _openEventDetail(EventModel event) async {
    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          event: event,
          organizer: _organizers[event.organizerId],
          categories: _categoriesFor(event.id),
          reviewBar: (barContext) => _reviewBar(barContext, event),
        ),
      ),
    );
    if (!mounted || action == null) return;
    await _confirmReview(event, action == 'approve');
  }

  Widget _reviewBar(BuildContext barContext, EventModel event) {
    final status = event.eventStatusId;
    if (status != EventStatus.pending) {
      final approved = status == EventStatus.approved;
      final color = approved ? _kGreen : _kRed;
      return Material(
        elevation: 8,
        shadowColor: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                approved ? Icons.check_circle : Icons.cancel,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                approved
                    ? 'Approved -- visible to everyone'
                    : 'Denied -- hidden from the public',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 8,
      shadowColor: const Color(0x44000000),
      borderRadius: BorderRadius.circular(30),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(barContext, 'deny'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kRed,
                    side: const BorderSide(color: Color(0x55E53935)),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text(
                    'DENY',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(barContext, 'approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text(
                    'APPROVE',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReview(EventModel event, bool approve) async {
    // The event page / card may be stale: if another reviewer has decided it
    // in the meantime, say so instead of letting this click overwrite it.
    final latest = _events.firstWhere((e) => e.id == event.id, orElse: () => event);
    if (latest.eventStatusId != EventStatus.pending) {
      _snack(
        'This event was already '
        '${latest.eventStatusId == EventStatus.approved ? 'approved' : 'denied'}'
        ' by another reviewer.',
      );
      return;
    }

    String? reason;
    if (approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Approve event?',
            style: TextStyle(color: _kTextDark),
          ),
          content: Text(
            '"${event.name}" will become visible to everyone.',
            style: const TextStyle(color: _kTextGrey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Approve',
                style: TextStyle(
                  color: _kGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      reason = await showDenyReasonDialog(
        context,
        title: 'Deny event?',
        message: '"${event.name}" will stay hidden from the public. The '
            'organizer will see your comment and must fix the event and '
            'press Save to send it for review again.',
      );
      if (reason == null) return;
    }

    try {
      await EventApiService.setEventStatus(
        eventId: event.id,
        eventStatusId: approve ? EventStatus.approved : EventStatus.denied,
        reason: reason,
      );
      _snack(approve ? 'Event approved' : 'Event denied');
      await _load(silent: true);
    } on ReviewConflictException catch (e) {
      // Someone else got there first: show their decision, not ours.
      _snack(e.message);
      await _load(silent: true);
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEventDetail(event),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
          if (event.eventStatusId == EventStatus.denied &&
              (event.denyReason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Reason: ${event.denyReason}',
                style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
              ),
            ),
        ],
            ),
          ),
        ),
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
