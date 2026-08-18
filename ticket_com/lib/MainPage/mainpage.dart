import 'package:flutter/material.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/MainPage/Panel/MainPanel.dart';
import 'package:ticket_com/MainPage/Panel/SettingPanel.dart';
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
      backgroundColor: Colors.black87,
      unselectedItemColor: Colors.grey,
      selectedItemColor: Colors.white,
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: l10nOf(context).home,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.book),
          label: l10nOf(context).ticket,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.favorite),
          label: l10nOf(context).wish,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.account_box_sharp),
          label: l10nOf(context).account,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings),
          label: l10nOf(context).setting,
        ),
      ],
    );
  }
}
