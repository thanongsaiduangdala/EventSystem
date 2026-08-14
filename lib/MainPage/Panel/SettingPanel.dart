import 'package:flutter/material.dart';
import 'package:reservation_system/services/auth_service.dart';
import 'package:reservation_system/DeveloperPage/MainPageDashboard.dart';
import 'package:reservation_system/LogSignPage/MainLoginSignUp.dart'; // adjust path

class SettingPanel extends StatefulWidget {
  const SettingPanel({super.key});

  @override
  State<SettingPanel> createState() => _SettingPanelState();
}

class _SettingPanelState extends State<SettingPanel> {
  bool _checkingDeveloper = false;

  Future<void> _openDeveloperDashboard() async {
    final session = AuthService.currentSession;
    if (session == null) return;

    setState(() => _checkingDeveloper = true);
    final isDeveloper = await AuthService.verifyDeveloperStatus();
    if (!mounted) return;
    setState(() => _checkingDeveloper = false);

    if (isDeveloper) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MainPageDashboard()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Developer access could not be verified')),
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
            ),
          const Divider(color: Colors.white24),
          if (session?.statusId == 3)
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
                  : const Icon(Icons.developer_mode, color: Colors.white70),
              title: const Text(
                'Developer Dashboard',
                style: TextStyle(color: Colors.white),
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
