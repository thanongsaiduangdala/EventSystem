import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ticket_com/DeveloperPage/deny_reason_dialog.dart';
import 'package:ticket_com/services/api_errors.dart';
import 'package:ticket_com/services/event_api_service.dart' show EventStatus;
import 'package:ticket_com/services/event_organizer_api_service.dart';
import 'package:ticket_com/services/review_live_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kSurface = Color(0xFFF5F6FA);
const Color _kGreen = Color(0xFF2E9E5B);
const Color _kAmber = Color(0xFFFB8C00);

/// Organizations tab: review organizations people submitted through
/// "Become an Organizer" and approve or deny them. Approving activates the
/// organization (events, team); denying leaves it inactive. Shown as one tab
/// of `EmployeeDashboardPage`.
class OrganizerApprovalsTab extends StatefulWidget {
  const OrganizerApprovalsTab({super.key, this.focusId});

  /// Organization to highlight (from a notification). The list switches to
  /// that organization's status so it is visible straight away.
  final int? focusId;

  @override
  State<OrganizerApprovalsTab> createState() => _OrganizerApprovalsTabState();
}

class _OrganizerApprovalsTabState extends State<OrganizerApprovalsTab> {
  List<EventOrganizer> _orgs = [];
  bool _loading = true;
  String? _error;
  int _filterStatusId = EventStatus.pending;
  bool _focusHandled = false;

  // Live updates: another reviewer (or an applicant) changed something, so
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
      if (change.isResync || change.isOrganization) _load(silent: true);
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
      final orgs = await EventOrganizerApiService.getAllOrganizers(
        includeUnapproved: true,
      );
      if (!mounted || seq != _loadSeq) return;
      // Newest first.
      orgs.sort((a, b) => b.id.compareTo(a.id));
      setState(() {
        _orgs = orgs;
        _loading = false;
        final focusId = widget.focusId;
        if (focusId != null && !_focusHandled) {
          _focusHandled = true;
          for (final o in orgs) {
            if (o.id == focusId) _filterStatusId = o.statusId;
          }
        }
      });
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

  int _count(int status) => _orgs.where((o) => o.statusId == status).length;

  List<EventOrganizer> get _filtered => _filterStatusId == 0
      ? _orgs
      : _orgs.where((o) => o.statusId == _filterStatusId).toList();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmReview(EventOrganizer org, bool approve) async {
    // The card may be stale: if another reviewer has decided it in the
    // meantime, say so instead of letting this click overwrite it.
    final latest = _orgs.firstWhere((o) => o.id == org.id, orElse: () => org);
    if (!latest.isPending) {
      _snack(
        'This organization was already '
        '${latest.isApproved ? 'approved' : 'denied'} by another reviewer.',
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
            'Approve organization?',
            style: TextStyle(color: _kTextDark),
          ),
          content: Text(
            '"${org.name}" will become active: its owner can create '
            'events and build a team.',
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
        title: 'Deny organization?',
        message: '"${org.name}" will stay inactive. The owner will see your '
            'comment and must fix the organization and press Save to send '
            'it for review again.',
      );
      if (reason == null) return;
    }

    try {
      if (approve) {
        await EventOrganizerApiService.approveOrganizer(org.id);
      } else {
        await EventOrganizerApiService.denyOrganizer(org.id, reason: reason!);
      }
      _snack(approve ? 'Organization approved' : 'Organization denied');
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
          'Organization Approvals',
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
          : _error != null && _orgs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(
                            backgroundColor: kAccent,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: kAccent,
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
                                      'No organizations found',
                                      style: TextStyle(color: _kTextGrey),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) => Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _orgCard(_filtered[i]),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryCard() {
    Widget stat(int count, String label, Color color) => Column(
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
            Text(label,
                style: const TextStyle(color: _kTextGrey, fontSize: 12.5)),
          ],
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          stat(_count(EventStatus.pending), 'Pending', _kAmber),
          stat(_count(EventStatus.approved), 'Approved', _kGreen),
          stat(_count(EventStatus.denied), 'Denied', Colors.redAccent),
        ],
      ),
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

  Widget _orgCard(EventOrganizer org) {
    final (statusLabel, statusColor) = switch (org.statusId) {
      EventStatus.approved => ('Approved', _kGreen),
      EventStatus.denied => ('Denied', Colors.redAccent),
      _ => ('Pending', _kAmber),
    };
    final desc = org.description ?? '';
    final focused = widget.focusId == org.id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: focused ? Border.all(color: kAccent, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: org.logoPath == null || org.logoPath!.isEmpty
                      ? Container(
                          color: kAccent.withValues(alpha: 0.12),
                          child: const Icon(Icons.apartment, color: kAccent),
                        )
                      : Image.network(
                          EventOrganizerApiService.fullImageUrl(org.logoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: kAccent.withValues(alpha: 0.12),
                            child: const Icon(Icons.apartment, color: kAccent),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.name,
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
                      'Owner account #${org.createdByAccountId}',
                      style: const TextStyle(color: _kTextGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
            ),
          ],
          if (org.isDenied && (org.denyReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Reason: ${org.denyReason}',
              style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
            ),
          ],
          // Only a pending organization can be decided. A denied one goes
          // back to pending when its owner edits and saves it again.
          if (org.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmReview(org, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Text('Deny'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _confirmReview(org, true),
                    style: FilledButton.styleFrom(backgroundColor: _kGreen),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
