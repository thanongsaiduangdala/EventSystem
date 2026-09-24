import 'package:flutter/material.dart';
import 'package:ticket_com/services/event_organizer_api_service.dart';
import 'package:ticket_com/services/identity_verification_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kSurface = Color(0xFFF5F6FA);

const int _kStatusPending = 1;
const int _kStatusApproved = 2;
const int _kStatusDenied = 3;

/// Employee Dashboard: review organizer identity verification requests and
/// approve (grants the applicant ORGANIZER access) or deny them. Available to
/// SUPERADMIN and EMPLOYEE accounts.
class EmployeeDashboardPage extends StatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage> {
  List<IdentityVerificationDetailModel> _items = [];
  List<VerificationTypeModel> _types = [];
  List<VerificationStatusModel> _statuses = [];

  bool _loading = true;
  String? _error;

  int _filterStatusId = 0; // 0 = all, else a VerificationStatusID

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
        IdentityVerificationApiService.getAllVerificationsWithAccounts(),
        IdentityVerificationApiService.getAllTypes(),
        IdentityVerificationApiService.getAllStatuses(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<IdentityVerificationDetailModel>;
        _types = results[1] as List<VerificationTypeModel>;
        _statuses = results[2] as List<VerificationStatusModel>;
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
      _items.where((i) => i.verification.verificationStatusId == _kStatusPending).length;

  int get _approvedCount =>
      _items.where((i) => i.verification.verificationStatusId == _kStatusApproved).length;

  int get _deniedCount =>
      _items.where((i) => i.verification.verificationStatusId == _kStatusDenied).length;

  List<IdentityVerificationDetailModel> get _filtered {
    if (_filterStatusId == 0) return _items;
    return _items
        .where((i) => i.verification.verificationStatusId == _filterStatusId)
        .toList();
  }

  String _typeNameFor(int id) {
    final matches = _types.where((t) => t.id == id);
    return matches.isNotEmpty ? matches.first.idType : 'Type #$id';
  }

  String _statusNameFor(int id) {
    final matches = _statuses.where((s) => s.id == id);
    return matches.isNotEmpty ? matches.first.statusName : 'Status #$id';
  }

  String _fmt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    final date =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmReview(IdentityVerificationDetailModel item, bool approve) async {
    final applicant = item.accountFullName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          approve ? 'Approve application?' : 'Deny application?',
          style: const TextStyle(color: _kTextDark),
        ),
        content: Text(
          approve
              ? 'Accept identity verification for $applicant and grant them '
                  'ORGANIZER access so they can create events.'
              : 'Reject identity verification for $applicant. Their account '
                  'status will not be changed.',
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
                color: approve ? const Color(0xFF2E9E5B) : Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final msg = approve
          ? await IdentityVerificationApiService.approveVerification(item.verification.id)
          : await IdentityVerificationApiService.denyVerification(item.verification.id);
      _snack(msg);
      await _load();
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  void _previewDocument(IdentityVerificationDetailModel item) {
    final path = item.verification.documentImagePath;
    if (path.trim().isEmpty) {
      _snack('No document image on this record');
      return;
    }
    final url = IdentityVerificationApiService.fullImageUrl(path);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _DocumentPreviewPage(url: url),
      ),
    );
  }

  void _openDetail(IdentityVerificationDetailModel item) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => VerificationDetailPage(
              item: item,
              typeNameFor: _typeNameFor,
              statusNameFor: _statusNameFor,
            ),
          ),
        )
        .then((_) => _load());
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
          'Employee Dashboard',
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
          : _error != null
              ? _errorBox()
              : Column(
                  children: [
                    _summaryCard(),
                    _filterBar(),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No identity verification records',
                                style: TextStyle(color: _kTextGrey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _reviewCard(_filtered[index]),
                                );
                              },
                            ),
                    ),
                  ],
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
          _stat(_pendingCount, 'Pending', const Color(0xFFFB8C00)),
          _stat(_approvedCount, 'Approved', const Color(0xFF2E9E5B)),
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
        Text(
          label,
          style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _filterBar() {
    final chips = <(int, String)>[
      (0, 'All'),
      (_kStatusPending, 'Pending'),
      (_kStatusApproved, 'Approved'),
      (_kStatusDenied, 'Denied'),
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

  Widget _reviewCard(IdentityVerificationDetailModel item) {
    final v = item.verification;
    final statusId = v.verificationStatusId;
    final isPending = statusId == _kStatusPending;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(item),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
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
                    child: const Icon(Icons.person_outline,
                        color: kAccent, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.accountFullName,
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
                          item.accountEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: _kTextGrey, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(statusId),
                ],
              ),
              const SizedBox(height: 12),
              _infoRow(Icons.fingerprint, 'ID Number', v.idNumberEncrypted),
              _infoRow(Icons.badge_outlined, 'Name on ID', v.fullNameOnId),
              _infoRow(Icons.verified_outlined, 'Type',
                  _typeNameFor(v.verificationTypeId)),
              if (item.organizers.isNotEmpty)
                _infoRow(Icons.store_outlined, 'Organization',
                    item.organizers.first.name),
              if (v.reviewedAtYmdt != null && v.reviewedAtYmdt!.isNotEmpty)
                _infoRow(Icons.history, 'Reviewed at', _fmt(v.reviewedAtYmdt)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _previewDocument(item),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0x145B4DFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: v.documentImagePath.trim().isEmpty
                            ? const Center(
                                child: Icon(Icons.image_outlined,
                                    color: Colors.grey, size: 36),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  IdentityVerificationApiService.fullImageUrl(
                                      v.documentImagePath),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      const Center(
                                    child: Icon(Icons.broken_image_outlined,
                                        color: Colors.grey, size: 36),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isPending)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _confirmReview(item, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E9E5B),
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
                        onPressed: () => _confirmReview(item, false),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: statusId == _kStatusApproved
                        ? const Color(0x142E9E5B)
                        : const Color(0x14E53935),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_statusNameFor(statusId)} by reviewer',
                    style: TextStyle(
                      color: statusId == _kStatusApproved
                          ? const Color(0xFF2E9E5B)
                          : Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View details',
                      style: TextStyle(
                        color: _kTextGrey,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: _kTextGrey, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
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
              maxLines: 1,
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
      _kStatusApproved => ('Approved', const Color(0xFF2E9E5B)),
      _kStatusDenied => ('Denied', Colors.redAccent),
      _ => ('Pending', const Color(0xFFFB8C00)),
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

class VerificationDetailPage extends StatefulWidget {
  final IdentityVerificationDetailModel item;
  final String Function(int) typeNameFor;
  final String Function(int) statusNameFor;

  const VerificationDetailPage({
    super.key,
    required this.item,
    required this.typeNameFor,
    required this.statusNameFor,
  });

  @override
  State<VerificationDetailPage> createState() => _VerificationDetailPageState();
}

class _VerificationDetailPageState extends State<VerificationDetailPage> {
  bool _busy = false;

  IdentityVerificationDetailModel get _item => widget.item;
  IdentityVerificationModel get _v => widget.item.verification;

  bool get _isPending => _v.verificationStatusId == _kStatusPending;

  String _accountStatusName(int id) {
    return switch (id) {
      1 => 'Customer',
      2 => 'Organizer',
      3 => 'SUPERADMIN',
      4 => 'EMPLOYEE',
      5 => 'Banned',
      _ => 'Account #$id',
    };
  }

  String _fmt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    final date =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _previewDocument() {
    final path = _v.documentImagePath;
    if (path.trim().isEmpty) {
      _snack('No document image on this record');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _DocumentPreviewPage(
          url: IdentityVerificationApiService.fullImageUrl(path),
        ),
      ),
    );
  }

  Future<void> _review(bool approve) async {
    final applicant = _item.accountFullName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          approve ? 'Approve application?' : 'Deny application?',
          style: const TextStyle(color: _kTextDark),
        ),
        content: Text(
          approve
              ? 'Accept identity verification for $applicant and grant them '
                  'ORGANIZER access so they can create events.'
              : 'Reject identity verification for $applicant. Their account '
                  'status will not be changed.',
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
                color: approve ? const Color(0xFF2E9E5B) : Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final msg = approve
          ? await IdentityVerificationApiService
              .approveVerification(_v.id)
          : await IdentityVerificationApiService.denyVerification(_v.id);
      if (!mounted) return;
      _snack(msg);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
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
          'Application Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _applicantCard(),
          const SizedBox(height: 12),
          _documentCard(),
          const SizedBox(height: 12),
          _sectionCard('Identity Verification', _verificationRows()),
          const SizedBox(height: 12),
          _sectionCard('Account', _accountRows()),
          const SizedBox(height: 12),
          _organizationCard(),
          const SizedBox(height: 12),
          if (_isPending) ...[
            FilledButton.icon(
              onPressed: _busy ? null : () => _review(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E9E5B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Approve & Grant Organizer Access',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _review(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Color(0x33E53935)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: const Text('Deny Application',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _applicantCard() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kAccent, Color(0xFF8E2DE2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _item.accountFullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _item.accountEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _kTextGrey, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _chip(
                _statusColor(_v.verificationStatusId),
                widget.statusNameFor(_v.verificationStatusId),
              ),
              const SizedBox(height: 6),
              _chip(
                const Color(0xFF1E88E5),
                _accountStatusName(_item.accountStatusId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _documentCard() {
    final path = _v.documentImagePath.trim();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.credit_card_outlined, 'Identity Document'),
          const SizedBox(height: 10),
          InkWell(
            onTap: _previewDocument,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0x145B4DFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: path.isEmpty
                  ? const Center(
                      child: Icon(Icons.image_outlined,
                          color: Colors.grey, size: 44),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        IdentityVerificationApiService.fullImageUrl(path),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.grey, size: 44),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.zoom_out_map, color: _kTextGrey, size: 16),
              SizedBox(width: 6),
              Text(
                'Tap the image to view it full screen',
                style: TextStyle(color: _kTextGrey, fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _verificationRows() {
    return [
      _row(Icons.numbers, 'Verification ID', '${_v.id}'),
      _row(Icons.verified_outlined, 'Status',
          widget.statusNameFor(_v.verificationStatusId)),
      _row(
          Icons.label_outline, 'ID Type', widget.typeNameFor(_v.verificationTypeId)),
      _row(Icons.fingerprint, 'ID Number', _v.idNumberEncrypted),
      _row(Icons.badge_outlined, 'Full Name on ID', _v.fullNameOnId),
      _row(Icons.cake_outlined, 'Date of Birth', _v.dateOfBirth),
      _row(Icons.schedule, 'Submitted At', _fmt(_v.submittedAtYmdt)),
      if (_v.reviewedByAccountId != null)
        _row(Icons.person_outline, 'Reviewed By',
            'Reviewer Account #${_v.reviewedByAccountId}'),
      if (_v.reviewedAtYmdt != null && _v.reviewedAtYmdt!.isNotEmpty)
        _row(Icons.history, 'Reviewed At', _fmt(_v.reviewedAtYmdt)),
    ];
  }

  List<Widget> _accountRows() {
    return [
      _row(Icons.numbers, 'Account ID', '${_v.accountId}'),
      _row(Icons.person_outline, 'Name', _item.accountFullName),
      _row(Icons.email_outlined, 'Email', _item.accountEmail),
      _row(Icons.phone_outlined, 'Phone', _item.accountPhone),
      _row(Icons.badge_outlined, 'Status',
          _accountStatusName(_item.accountStatusId)),
    ];
  }

  Widget _organizationCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.store_outlined, 'Organization'),
          const SizedBox(height: 10),
          if (_item.organizers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No organization profile has been created for this applicant yet.',
                style: TextStyle(color: _kTextGrey, fontSize: 13),
              ),
            )
          else
            for (var i = 0; i < _item.organizers.length; i++) ...[
              if (i > 0) const Divider(color: Color(0x14000000), height: 20),
              _organizerTile(_item.organizers[i]),
            ],
        ],
      ),
    );
  }

  Widget _organizerTile(EventOrganizer org) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 56,
            height: 56,
            color: const Color(0x145B4DFF),
            child: org.logoPath == null || org.logoPath!.trim().isEmpty
                ? const Icon(Icons.storefront_outlined,
                    color: kAccent, size: 26)
                : Image.network(
                    EventOrganizerApiService.fullImageUrl(org.logoPath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.storefront_outlined,
                      color: kAccent,
                      size: 26,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                org.name,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '#${org.id}  •  Created by Account #${org.createdByAccountId}',
                style: const TextStyle(color: _kTextGrey, fontSize: 12),
              ),
              if (org.description != null &&
                  org.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  org.description!,
                  style: const TextStyle(
                    color: _kTextGrey,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(int statusId) {
    return switch (statusId) {
      _kStatusApproved => const Color(0xFF2E9E5B),
      _kStatusDenied => Colors.redAccent,
      _ => const Color(0xFFFB8C00),
    };
  }

  Widget _chip(Color color, String label) {
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

  Widget _sectionCard(String title, List<Widget> rows) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.info_outline, title),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: kAccent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kTextGrey, size: 17),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
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

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

class _DocumentPreviewPage extends StatelessWidget {
  final String url;
  const _DocumentPreviewPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Identity document'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}