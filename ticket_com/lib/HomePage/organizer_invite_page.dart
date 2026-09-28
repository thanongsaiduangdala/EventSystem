import 'package:flutter/material.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_organizer_api_service.dart';
import 'package:ticket_com/services/identity_verification_api_service.dart';
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

import 'identity_verification_submit_page.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

// MemberStatusID values (mirror memberstatusinfo).
const int _kMemberPending = 1;
const int _kMemberActive = 2;
const int _kMemberDeclined = 3;
const int _kMemberRemoved = 4;

// VerificationStatusID values.
const int _kVerificationPending = 1;
const int _kVerificationApproved = 2;

/// Invite/join page reached from an `org_invite:<MemberID>` notification.
///
/// Walks the onboarding sequence: load the membership row, then depending on
/// its state either show the organization details with Join/Decline, ask the
/// invitee to get identity-verified first (with a submission form), or show a
/// terminal state (already joined / declined / revoked).
class OrganizerInvitePage extends StatefulWidget {
  const OrganizerInvitePage({super.key, required this.memberId});

  final int memberId;

  @override
  State<OrganizerInvitePage> createState() => _OrganizerInvitePageState();
}

class _OrganizerInvitePageState extends State<OrganizerInvitePage> {
  bool _loading = true;
  bool _busy = false;
  String? _error;

  OrganizerMemberDetail? _detail;
  List<IdentityVerificationModel> _verifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  UserSession? get _session => AuthService.currentSession;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = _session;
      if (session == null) {
        throw Exception('You must be logged in');
      }
      final detail =
          await OrganizerMemberApiService.getMemberDetail(widget.memberId);
      final verifications = await IdentityVerificationApiService
          .getVerificationsByAccount(session.accountId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _verifications = verifications;
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

  bool get _identityVerified =>
      _verifications.any((v) => v.verificationStatusId == _kVerificationApproved);

  bool get _isMyInvitation {
    final session = _session;
    final detail = _detail;
    if (session == null || detail == null) return false;
    return detail.accountId == session.accountId;
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await OrganizerMemberApiService.acceptInvite(widget.memberId);
      await _load();
      if (!mounted) return;
      _snack('Welcome aboard! You have joined the team.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not accept: $e');
    }
  }

  Future<void> _decline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Decline invitation?',
          style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You can still be invited again by the organization later.',
          style: TextStyle(color: _kTextGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: _kTextGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Decline',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await OrganizerMemberApiService.declineInvite(widget.memberId);
      await _load();
      if (!mounted) return;
      _snack('Invitation declined.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not decline: $e');
    }
  }

  Future<void> _openVerificationForm() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const IdentityVerificationSubmitPage(),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: const Text(
          'Team Invitation',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kAccent),
            )
          : _error != null
              ? _errorBox()
              : _body(),
    );
  }

  Widget _body() {
    final detail = _detail;
    if (detail == null) return _errorBox();

    switch (detail.memberStatusId) {
      case _kMemberActive:
        return _statusView(
          icon: Icons.verified_user,
          color: const Color(0xFF2E9E5B),
          title: 'You are already a member',
          message: 'You have joined "${detail.organizerName}" as ${_roleText(detail)}.',
        );
      case _kMemberDeclined:
        return _statusView(
          icon: Icons.do_not_disturb_alt,
          color: const Color(0xFF757575),
          title: 'Invitation declined',
          message: 'You declined the invitation to join "${detail.organizerName}".',
        );
      case _kMemberRemoved:
        return _statusView(
          icon: Icons.block,
          color: const Color(0xFFE53935),
          title: 'Invitation revoked',
          message:
              'The organization has removed or cancelled this invitation, so you '
              'can no longer join through it.',
        );
      case _kMemberPending:
      default:
        if (!_isMyInvitation) {
          return _statusView(
            icon: Icons.lock_outline,
            color: const Color(0xFFE53935),
            title: 'Invitation not for you',
            message: 'This invitation belongs to another account.',
          );
        }
        if (_identityVerified) {
          return _joinView(detail);
        }
        return _verificationGate(detail);
    }
  }

  // ---------------- pending + identity-verified: show org + join ----------------

  Widget _joinView(OrganizerMemberDetail detail) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _organizationCard(detail),
        const SizedBox(height: 16),
        _row('Team role', _roleText(detail)),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _busy ? null : _join,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E9E5B),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text(
            'Accept & Join Team',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _decline,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE53935),
            side: const BorderSide(color: Color(0xFFE53935)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Decline Invitation'),
        ),
      ],
    );
  }

  Widget _organizationCard(OrganizerMemberDetail detail) {
    final logoPath = detail.organizerLogoPath;
    return Container(
      padding: const EdgeInsets.all(20),
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
              logoPath == null || logoPath.isEmpty
                  ? Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.storefront, color: kAccent),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        EventOrganizerApiService.fullImageUrl(logoPath),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.storefront, color: kAccent),
                        ),
                      ),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You\'re invited to join',
                      style: TextStyle(
                        color: _kTextGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail.organizerName.isEmpty
                          ? 'Organization'
                          : detail.organizerName,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((detail.organizerDescription ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              detail.organizerDescription!.trim(),
              style: const TextStyle(
                color: _kTextGrey,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: _kTextGrey, fontSize: 13.5),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- pending: identity verification gate ----------------

  Widget _verificationGate(OrganizerMemberDetail detail) {
    final pending = _verifications
        .any((v) => v.verificationStatusId == _kVerificationPending);
    final denied =
        _verifications.isNotEmpty && !_identityVerified && !pending;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: (pending
                          ? const Color(0xFFFF9800)
                          : denied
                              ? const Color(0xFFE53935)
                              : kAccent)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  pending
                      ? Icons.hourglass_top
                      : denied
                          ? Icons.gpp_bad
                          : Icons.badge_outlined,
                  color: pending
                      ? const Color(0xFFFF9800)
                      : denied
                          ? const Color(0xFFE53935)
                          : kAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                pending
                    ? 'Identity verification pending'
                    : denied
                        ? 'Identity verification needed'
                        : 'Verify your identity to join',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pending
                    ? 'Your identity details have been submitted to "${detail.organizerName}" '
                        'and are waiting for admin review. Once approved you can accept '
                        'the invitation here.'
                    : denied
                        ? 'Your previous identity verification was not approved. Submit '
                            'a new one with the correct information to continue joining '
                            '"${detail.organizerName}".'
                        : 'To join "${detail.organizerName}", you first need a verified '
                            'identity. Fill in your details below and an admin will '
                            'approve it before you can accept the invitation.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextGrey,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _openVerificationForm,
          style: FilledButton.styleFrom(
            backgroundColor: kAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: pending
              ? const Icon(Icons.refresh)
              : const Icon(Icons.badge_outlined),
          label: Text(
            pending ? 'Check status again' : 'Complete identity verification',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _decline,
          child: const Text(
            'Decline invitation instead',
            style: TextStyle(color: Color(0xFFE53935)),
          ),
        ),
      ],
    );
  }

  String _roleText(OrganizerMemberDetail detail) =>
      detail.roleName.isEmpty ? 'Member' : detail.roleName;

  Widget _statusView({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextGrey,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
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
              _error ?? 'Could not load the invitation.',
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