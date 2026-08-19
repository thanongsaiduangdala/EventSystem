import 'package:flutter/material.dart';
import 'package:ticket_com/DeveloperPage/attendee_response_form.dart';
import 'ticket_attendence_form.dart';
import 'orders_info_form.dart';

class AttendeeControllerPage extends StatefulWidget {
  const AttendeeControllerPage({super.key});

  @override
  State<AttendeeControllerPage> createState() => _AttendeeControllerPageState();
}

class _AttendeeControllerPageState extends State<AttendeeControllerPage> {
  final GlobalKey<TicketAttendenceFormState> _attendeeFormKey = GlobalKey();
  final GlobalKey<OrdersInfoFormState> _ordersFormKey = GlobalKey();
  final GlobalKey<AttendeeResponseFormState> _responseFormkey = GlobalKey();
  int _selectedIndexId = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _body(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _body() {
    switch (_selectedIndexId) {
      case 0:
        return TicketAttendenceForm(key: _attendeeFormKey);
      case 1:
        return OrdersInfoForm(key: _ordersFormKey);
      case 2:
        return AttendeeResponseForm(key: _responseFormkey);
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
      backgroundColor: Colors.black87,
      unselectedItemColor: Colors.grey,
      selectedItemColor: Colors.white,
      currentIndex: _selectedIndexId,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.local_activity),
          label: "ticket attendence",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          label: "order info",
        ),
      ],
    );
  }
}
