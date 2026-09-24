import 'package:flutter/material.dart';
import 'account_info_form.dart';

class AccountControllerPage extends StatefulWidget {
  const AccountControllerPage({super.key});

  @override
  State<AccountControllerPage> createState() => _AccountControllerPageState();
}

class _AccountControllerPageState extends State<AccountControllerPage> {
  final GlobalKey<AccountInfoFormState> _accountFormKey = GlobalKey();
  int _selectedIndexId = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      body: _body(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _body() {
    switch (_selectedIndexId) {
      case 0:
        return AccountInfoForm(key: _accountFormKey);
      case 1:
        return const Center(
          child: Text('Coming soon', style: TextStyle(color: Color(0xFF212121))),
        );
      default:
        return const Center();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndexId = index;
    });
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      unselectedItemColor: Colors.grey,
      selectedItemColor: Color(0xFF5B4DFF),
      currentIndex: _selectedIndexId,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.account_circle),
          label: "Account",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: "Account want",
        ),
      ],
    );
  }
}
