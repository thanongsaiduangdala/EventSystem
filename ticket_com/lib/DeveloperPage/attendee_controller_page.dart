import 'package:flutter/material.dart';
import 'ticket_attendence_form.dart';
import 'orders_info_form.dart';
import 'attendee_response_form.dart';
import 'identity_verification_form.dart';

class AttendeeControllerPage extends StatefulWidget {
  const AttendeeControllerPage({super.key});

  @override
  State<AttendeeControllerPage> createState() => _AttendeeControllerPageState();
}

class _AttendeeControllerPageState extends State<AttendeeControllerPage> {
  final GlobalKey<TicketAttendenceFormState> _attendeeFormKey = GlobalKey();
  final GlobalKey<OrdersInfoFormState> _ordersFormKey = GlobalKey();
  final GlobalKey<AttendeeResponseFormState> _responseFormKey = GlobalKey();
  final GlobalKey<IdentityVerificationFormState> _identityFormKey = GlobalKey();
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
        return AttendeeResponseForm(key: _responseFormKey);
      case 3:
        return IdentityVerificationForm(key: _identityFormKey);
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
      type: BottomNavigationBarType.fixed,
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
        BottomNavigationBarItem(
          icon: Icon(Icons.question_answer_outlined),
          label: "responses",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.verified_user_outlined),
          label: "identity verification",
        ),
      ],
    );
  }
}
