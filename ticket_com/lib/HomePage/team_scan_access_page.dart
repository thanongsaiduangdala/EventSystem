import 'package:flutter/material.dart';
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

class TeamScanAccessPage extends StatefulWidget {
  const TeamScanAccessPage({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  final int eventId;
  final String eventName;

  @override
  State<TeamScanAccessPage> createState() => _TeamScanAccessPageState();
}

class _TeamScanAccessPageState extends State<TeamScanAccessPage> {
  bool _loading = true;
  String? _error;
  EventScanAccess? _access;
  final Set<int> _busy = {};
  bool _busyAll = false;

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
      final access =
          await OrganizerMemberApiService.getEventScanAccess(widget.eventId);
      if (!mounted) return;
      setState(() {
        _access = access;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleAll(bool value) async {
    final access = _access;
    if (access == null || _busyAll) return;
    setState(() {
      _busyAll = true;
      access.scanEnabled = value;
    });
    try {
      await OrganizerMemberApiService.setEventScanEnabled(
        eventId: widget.eventId,
        enabled: value,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => access.scanEnabled = !value);
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busyAll = false);
    }
  }

  Future<void> _toggleMember(ScanAccessMember member, bool value) async {
    if (_busy.contains(member.memberId)) return;
    setState(() {
      _busy.add(member.memberId);
      member.canScan = value;
    });
    try {
      await OrganizerMemberApiService.setMemberScanAccess(
        eventId: widget.eventId,
        memberId: member.memberId,
        canScan: value,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => member.canScan = !value);
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy.remove(member.memberId));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        foregroundColor: _kTextDark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan access',
              style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800),
            ),
            Text(
              widget.eventName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kTextGrey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }
    final access = _access;
    if (_error != null || access == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error ?? 'Could not load scan access.',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kAccent,
              value: access.scanEnabled,
              onChanged: _busyAll ? null : _toggleAll,
              title: const Text(
                'Everyone assigned can scan',
                style: TextStyle(
                  color: _kTextDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                access.scanEnabled
                    ? 'All assigned volunteers and staff can scan right now.'
                    : 'Scanning is off. Only the people you switch on below can scan.',
                style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Individual access',
            style: TextStyle(
              color: _kTextDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            access.scanEnabled
                ? 'Everyone can scan while the switch above is on.'
                : 'Switch on the people who may scan this event.',
            style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          if (access.members.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'No volunteers or staff are assigned to this event yet. '
                'Assign them from Manage Team.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextGrey, fontSize: 13),
              ),
            )
          else
            for (final m in access.members) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kAccent,
                  value: access.scanEnabled || m.canScan,
                  onChanged: (access.scanEnabled || _busy.contains(m.memberId))
                      ? null
                      : (v) => _toggleMember(m, v),
                  title: Text(
                    m.fullName.isEmpty ? 'Member #${m.memberId}' : m.fullName,
                    style: const TextStyle(
                      color: _kTextDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(
                    m.teamRoleName,
                    style: const TextStyle(color: _kTextGrey, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}
