import 'package:flutter/material.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/MainPage/Panel/MainPanel.dart';
import 'package:ticket_com/MainPage/Panel/MapPanel.dart';
import 'package:ticket_com/MainPage/Panel/SettingPanel.dart';
import 'package:ticket_com/MainPage/Panel/TicketPanel.dart';
import 'package:ticket_com/MainPage/Panel/WishPanel.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/notification_service.dart';
//import 'package:ticket_com/main.dart';

class Mainpage extends StatefulWidget {
  const Mainpage({super.key});

  @override
  State<Mainpage> createState() => _MainpageState();
}

class _MainpageState extends State<Mainpage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start the live notification stream as soon as the app shell exists, so
    // it keeps running (and the Home badge keeps updating) on every tab, not
    // only while the home page is on screen.
    NotificationService.instance.syncSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background: the stream may have been cut by the OS,
    // so reconnect and catch up on anything that arrived meanwhile.
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.syncSession();
      NotificationService.instance.refresh(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _body(),
      bottomNavigationBar: _btnNavBar(context),
    );
  }

  Widget _body() {
    switch (_selectedIndex) {
      case 0:
        return const Mainpanel();
      case 1:
        return const TicketPanel();
      case 2:
        return const WishPanel();
      case 3:
        return const MapPanel();
      case 4:
        return const SettingPanel();
      default:
        return const Center(
          child: Text('Coming soon', style: TextStyle(color: Colors.white)),
        );
    }
  }

  Widget _btnNavBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF3D5AFE),
      unselectedItemColor: Colors.grey,
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      items: [
        BottomNavigationBarItem(
          icon: _homeIcon(Icons.home_outlined),
          activeIcon: _homeIcon(Icons.home),
          label: l10nOf(context).home,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.confirmation_number_outlined),
          activeIcon: const Icon(Icons.confirmation_number),
          label: l10nOf(context).ticket,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.favorite_outline),
          activeIcon: const Icon(Icons.favorite),
          label: l10nOf(context).wish,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.place_outlined),
          activeIcon: const Icon(Icons.place),
          label: l10nOf(context).map,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined),
          activeIcon: const Icon(Icons.settings),
          label: l10nOf(context).setting,
        ),
      ],
    );
  }

  /// Home tab icon with a live unread-notification count on its top-right
  /// corner. Only shown while the user is on another tab -- on the Home tab
  /// itself the bell on the home page already shows the count.
  Widget _homeIcon(IconData icon) {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        final unread = NotificationService.instance.unreadCount;
        final showBadge =
            _selectedIndex != 0 &&
            AuthService.currentSession != null &&
            unread > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon),
            if (showBadge)
              Positioned(
                top: -5,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7043),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
