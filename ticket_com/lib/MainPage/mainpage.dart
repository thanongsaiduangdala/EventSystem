import 'package:flutter/material.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/MainPage/Panel/MainPanel.dart';
import 'package:ticket_com/MainPage/Panel/MapPanel.dart';
import 'package:ticket_com/MainPage/Panel/SettingPanel.dart';
import 'package:ticket_com/MainPage/Panel/TicketPanel.dart';
import 'package:ticket_com/MainPage/Panel/WishPanel.dart';
//import 'package:ticket_com/main.dart';

class Mainpage extends StatefulWidget {
  const Mainpage({super.key});

  @override
  State<Mainpage> createState() => _MainpageState();
}

class _MainpageState extends State<Mainpage> {
  int _selectedIndex = 0;

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
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home),
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
}
