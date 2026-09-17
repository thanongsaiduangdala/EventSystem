import 'package:flutter/material.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/DeveloperPage/MainPageDashboard.dart';
import 'package:ticket_com/LogSignPage/MainLoginSignUp.dart'; // adjust path

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

    return Container(
      color: Colors.black,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (session != null)
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white70),
              title: Text(
                '${session.firstname} ${session.lastname}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                session.email,
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: roleName == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D5AFE),
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
            ),
          const Divider(color: Colors.white24),
          if (canAdmin)
            ListTile(
              leading: _checkingDeveloper
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.admin_panel_settings, color: Colors.white70),
              title: const Text(
                'Admin Dashboard',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Manage events, accounts & content',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: _checkingDeveloper ? null : _openDeveloperDashboard,
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
