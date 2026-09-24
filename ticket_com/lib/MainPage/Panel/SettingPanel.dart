import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/DeveloperPage/MainPageDashboard.dart';
import 'package:ticket_com/DeveloperPage/employee_dashboard_page.dart';
import 'package:ticket_com/HomePage/become_organizer_page.dart';
import 'package:ticket_com/HomePage/my_profile_page.dart';
import 'package:ticket_com/HomePage/organizer_dashboard_page.dart';
import 'package:ticket_com/HomePage/organizers_page.dart';
import 'package:ticket_com/LogSignPage/MainLoginSignUp.dart'; // adjust path
import 'package:ticket_com/main.dart';
import 'package:ticket_com/services/auth_service.dart';
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
      case 4:
        return 'EMPLOYEE';
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

  Future<void> _openEmployeeDashboard() async {
    final session = AuthService.currentSession;
    final canUse = (session?.isSuperAdmin ?? false) ||
        (session?.isEmployee ?? false);
    if (!canUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SUPERADMIN or EMPLOYEE access is required'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmployeeDashboardPage()),
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Mainloginsignup()),
      (route) => false,
    );
  }

  Future<void> _pickLanguage() async {
    final l10n = l10nOf(context);
    final current = appLocale.value.languageCode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.language,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _languageOption(
                  name: l10n.english,
                  nativeName: 'English',
                  selected: current == 'en',
                  onTap: () => Navigator.pop(context, 'en'),
                ),
                _languageOption(
                  name: l10n.lao,
                  nativeName: 'ລາວ',
                  selected: current == 'lo',
                  onTap: () => Navigator.pop(context, 'lo'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && selected != current) {
      appLocale.value = Locale(selected);
    }
  }

  Widget _languageOption({
    required String name,
    required String nativeName,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.language, color: kAccent, size: 22),
      ),
      title: Text(
        name,
        style: const TextStyle(
          color: Color(0xFF212121),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        nativeName,
        style: const TextStyle(color: Color(0xFF757575), fontSize: 12.5),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: kAccent, size: 22)
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.currentSession;
    final roleName = _roleName;
    final canAdmin = session?.isSuperAdmin ?? false;
    final canEmployee = (session?.isSuperAdmin ?? false) ||
        (session?.isEmployee ?? false);
    final isOrganizer = (session?.isOrganizer ?? false) ||
        (session?.isSuperAdmin ?? false);

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
            if (session != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _profileCard(session, roleName),
              ),
              const SizedBox(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _actionsCard(canAdmin, canEmployee, isOrganizer),
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
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 22),
                color: const Color(0xFF212121),
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Text(
            'Settings',
            style: TextStyle(
              color: Color(0xFF212121),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

  Widget _actionsCard(bool canAdmin, bool canEmployee, bool isOrganizer) {
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
          if (canEmployee)
            _actionTile(
              icon: Icons.badge_outlined,
              iconColor: const Color(0xFF00897B),
              title: 'Employee Dashboard',
              subtitle: 'Approve organizer identity verification',
              titleColor: const Color(0xFF212121),
              subtitleColor: const Color(0xFF757575),
              trailing: const Icon(Icons.chevron_right, color: Colors.black26),
              onTap: _openEmployeeDashboard,
            ),
          if (canEmployee) const _CardDivider(),
          _actionTile(
            icon: Icons.person_outline,
            iconColor: kAccent,
            title: 'Profile',
            subtitle: 'Edit your profile & interests',
            titleColor: const Color(0xFF212121),
            subtitleColor: const Color(0xFF757575),
            trailing: const Icon(Icons.chevron_right, color: Colors.black26),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyProfilePage(),
                ),
              );
            },
          ),
          const _CardDivider(),
          _actionTile(
            icon: Icons.business_outlined,
            iconColor: const Color(0xFF1E88E5),
            title: 'Organizers',
            subtitle: 'Verified organizer users',
            titleColor: const Color(0xFF212121),
            subtitleColor: const Color(0xFF757575),
            trailing: const Icon(Icons.chevron_right, color: Colors.black26),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrganizersPage(),
                ),
              );
            },
          ),
          const _CardDivider(),
          if (isOrganizer)
            _actionTile(
              icon: Icons.dashboard_customize_outlined,
              iconColor: const Color(0xFFFF8F00),
              title: 'Organizers Dashboard',
              subtitle: 'Create events & manage your team',
              titleColor: const Color(0xFF212121),
              subtitleColor: const Color(0xFF757575),
              trailing: const Icon(Icons.chevron_right, color: Colors.black26),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrganizerDashboardPage(),
                  ),
                );
              },
            )
          else
            _actionTile(
              icon: Icons.storefront_outlined,
              iconColor: const Color(0xFFFF8F00),
              title: l10nOf(context).becomeOrganizer,
              subtitle: 'Verify your identity to organize events',
              titleColor: const Color(0xFF212121),
              subtitleColor: const Color(0xFF757575),
              trailing: const Icon(Icons.chevron_right, color: Colors.black26),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BecomeOrganizerPage(),
                  ),
                );
              },
            ),
          const _CardDivider(),
          _actionTile(
            icon: Icons.language,
            iconColor: const Color(0xFF00897B),
            title: l10nOf(context).language,
            subtitle: 'English / ລາວ',
            titleColor: const Color(0xFF212121),
            subtitleColor: const Color(0xFF757575),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appLocale.value.languageCode == 'lo'
                      ? l10nOf(context).lao
                      : l10nOf(context).english,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
            onTap: _pickLanguage,
          ),
          const _CardDivider(),
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