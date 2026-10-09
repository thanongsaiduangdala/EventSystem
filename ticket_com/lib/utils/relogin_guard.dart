import 'package:flutter/material.dart';
import 'package:ticket_com/LogSignPage/MainLoginSignUp.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

const String kReloginTitle = 'Log in again to continue';
const String kReloginMessage =
    'Your account was just upgraded (for example, your identity was '
    'approved). For security, please log out and log back in before using '
    'organization pages.';

/// Logs out and returns to the login screen, so the next login issues a new
/// token that matches the account's current role.
Future<void> logoutToLogin(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  await AuthService.logout();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const Mainloginsignup()),
    (route) => false,
  );
}

/// Call before opening any organization / team page. Returns true when the
/// page may be opened. When the login token is out of date (the role changed
/// after login, e.g. identity verification was approved) it shows a dialog
/// asking the user to log out and back in, and returns false.
Future<bool> ensureOrgAccess(BuildContext context) async {
  final stale = await AuthService.checkSessionStale();
  if (!stale) return true;
  if (!context.mounted) return false;
  await showReloginDialog(context);
  return false;
}

Future<void> showReloginDialog(BuildContext context) async {
  final logout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        kReloginTitle,
        style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800),
      ),
      content: const Text(
        kReloginMessage,
        style: TextStyle(color: _kTextGrey, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(backgroundColor: kAccent),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (logout == true && context.mounted) {
    await logoutToLogin(context);
  }
}

/// Full-page replacement for an organization page while the token is stale.
class ReloginRequiredView extends StatelessWidget {
  const ReloginRequiredView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset, color: kAccent, size: 40),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          kReloginTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kTextDark,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          kReloginMessage,
          textAlign: TextAlign.center,
          style: TextStyle(color: _kTextGrey, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => logoutToLogin(context),
          style: FilledButton.styleFrom(
            backgroundColor: kAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.logout),
          label: const Text(
            'Log out and log in again',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Compact notice shown on the Settings screen while the token is stale.
class ReloginBanner extends StatelessWidget {
  const ReloginBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF8A6D00)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Your account was upgraded. Log out and log back in to unlock '
              'your organization pages.',
              style: TextStyle(
                color: Color(0xFF6B5400),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => logoutToLogin(context),
            style: TextButton.styleFrom(foregroundColor: kAccent),
            child: const Text(
              'Log out',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
