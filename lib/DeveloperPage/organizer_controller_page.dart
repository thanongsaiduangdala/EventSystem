import 'package:flutter/material.dart';

class OrganizerControllerPage extends StatefulWidget {
  const OrganizerControllerPage({super.key});

  @override
  State<OrganizerControllerPage> createState() =>
      _OrganizerControllerPageState();
}

class _OrganizerControllerPageState extends State<OrganizerControllerPage> {
  @override

  int _selectedIndexId = 0;
  Widget build(BuildContext context) {
    return Scaffold(body: _body(), bottomNavigationBar: _BTNNavBar());

   
  }

  widget _body(){
    return  //<- return stuff at the bottom nav
  }
  
  void _onItemTapped(int index){
    setState(() {
      _selectedIndexId = index;
    });
  }

  Widget _BTNNavBar(){
    return BottomNavigationBar(
      currentIndex: _selectedIndexId,
      onTap: _onItemTapped,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.business), label: "Event Organizer"),
        BottomNavigationBarItem(icon: Icon(Icons.person_2_outlined), label: "Organizer member"),
        BottomNavigationBarItem(icon: Icon(Icons.group_work_outlined), label: "Event stuff"),
      ],
      );
  }
}
