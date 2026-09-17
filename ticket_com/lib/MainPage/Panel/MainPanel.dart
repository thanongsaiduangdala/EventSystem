import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/home_page.dart';

class Mainpanel extends StatefulWidget {
  const Mainpanel({super.key});

  @override
  State<Mainpanel> createState() => _MainpanelState();
}

class _MainpanelState extends State<Mainpanel> {
  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}
