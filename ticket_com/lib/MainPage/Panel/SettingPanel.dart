import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/DeveloperPage/MainPageDashboard.dart';
import 'package:ticket_com/LogSignPage/MainLoginSignUp.dart'; // adjust path
import 'package:ticket_com/utils/category_colors.dart';

class SettingPanel extends StatefulWidget {
  const SettingPanel({super.key});

  @override
  State<SettingPanel> createState() => _SettingPanelState();
}

class _SettingPanelState extends State<SettingPanel> {
  bool _checkingDeveloper = false;

  String? get _roleName {
    final role = AuthService.currentSession?.role;
    if (role != null && role.isNotEmpty) return role;
    switch (AuthService.currentSession?.statusId) {
      case 1:
        return 'CUSTOMER';
      case 2:
        return 'ORGANIZER';
      case 3:
        return 'SUPERADMIN';
    }
    return null;
  }

  Future<void> _openDeveloperDashboard() async {
    final session = AuthService.currentSession;
    if (session == null) return;

    setState(() => _checkingDeveloper = true);
    await AuthService.refreshRbac();
    final isDeveloper = AuthService.currentSession?.isSuperAdmin ?? false;
    if (!mounted) return;
    setState(() => _checkingDeveloper = false);

    if (isDeveloper) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MainPageDashboard()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SUPERADMIN access is required')),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Mainloginsignup()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.currentSession;
    final roleName = _roleName;
    final canAdmin = session?.isSuperAdmin ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _header(context),
            const SizedBox(height: 16),
            if (session != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _profileCard(session, roleName),
              ),
            if (session != null) const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _actionsCard(canAdmin),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad + 16, 16, 0),
      child: const Text(
        'Settings',
        style: TextStyle(
          color: Color(0xFF212121),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _profileCard(dynamic session, String? roleName) {
    return Container(
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kAccent, Color(0xFF8E2DE2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.firstname} ${session.lastname}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF757575),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (roleName != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                roleName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionsCard(bool canAdmin) {
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
      child: Column(
        children: [
          if (canAdmin)
            _actionTile(
              icon: Icons.admin_panel_settings,
              iconColor: kAccent,
              title: 'Admin Dashboard',
              subtitle: 'Manage events, accounts & content',
              titleColor: const Color(0xFF212121),
              subtitleColor: const Color(0xFF757575),
              trailing: _checkingDeveloper
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kAccent,
                      ),
                    )
                  : const Icon(Icons.chevron_right, color: Colors.black26),
              onTap: _checkingDeveloper ? null : _openDeveloperDashboard,
            ),
          if (canAdmin) const _CardDivider(),
          _actionTile(
            icon: Icons.logout,
            iconColor: Colors.redAccent,
            title: 'Logout',
            titleColor: Colors.redAccent,
            trailing: const Icon(Icons.chevron_right, color: Colors.black26),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    String? subtitle,
    Color? subtitleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12.5,
              ),
            ),
      trailing: trailing,
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0x14000000),
    );
  }
}