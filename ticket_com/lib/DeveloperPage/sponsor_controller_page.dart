import 'package:flutter/material.dart';
import 'sponsor_info_form.dart';

class SponsorControllerPage extends StatefulWidget {
  const SponsorControllerPage({Key? key}) : super(key: key);

  @override
  State<SponsorControllerPage> createState() => _SponsorControllerPageState();
}

class _SponsorControllerPageState extends State<SponsorControllerPage> {
  final GlobalKey<SponsorInfoFormState> _sponsorFormKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _body(),
    );
  }

  Widget _body() {
    return SponsorInfoForm(key: _sponsorFormKey);
  }
}
