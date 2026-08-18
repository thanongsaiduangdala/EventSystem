import 'package:flutter/material.dart';
import 'event_organizer_form.dart';
import 'organizer_member_form.dart';
import 'event_staff_form.dart';

class OrganizerControllerPage extends StatefulWidget {
  const OrganizerControllerPage({super.key});

  @override
  State<OrganizerControllerPage> createState() =>
      _OrganizerControllerPageState();
}

class _OrganizerControllerPageState extends State<OrganizerControllerPage> {
  int _selectedIndexId = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _body(),
      bottomNavigationBar: _bottomNavBar(),
    );
  }

  Widget _body() {
    switch (_selectedIndexId) {
      case 0: // Event Organizer tab
        return const EventOrganizerForm();
      case 1: // Organizer member tab
        return const OrganizerMemberForm();
      case 2: // Event stuff tab
        return const EventStaffForm();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndexId = index;
    });
  }

  Widget _bottomNavBar() {
    return BottomNavigationBar(
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.white,
      backgroundColor: Colors.black87,
      currentIndex: _selectedIndexId,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.business),
          label: "Event Organizer",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_2_outlined),
          label: "Organizer member",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group_work_outlined),
          label: "Event stuff",
        ),
      ],
    );
  }
}
