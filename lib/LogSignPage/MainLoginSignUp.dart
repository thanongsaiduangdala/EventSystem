import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/LogSignPage/LoginPage.dart';
import 'package:ticket_com/LogSignPage/SignUpPage.dart';
import 'package:ticket_com/main.dart';

class Mainloginsignup extends StatefulWidget {
  const Mainloginsignup({super.key});

  @override
  State<Mainloginsignup> createState() => _MainloginsignupState();
}

class _MainloginsignupState extends State<Mainloginsignup> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _languageToggle(),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.fromARGB(255, 182, 61, 61),
            Color.fromARGB(255, 117, 27, 27),
            Color.fromARGB(255, 34, 7, 7),
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10nOf(context).ticketCom,
                  style: const TextStyle(
                    fontSize: 30,
                    letterSpacing: 10,
                    color: Colors.white,
                  ),
                ),
                Icon(Symbols.chair, color: Color(0xFFE3E3E3), size: 180),
                SizedBox(height: 200),
                Text(
                  l10nOf(context).welcome,
                  style: TextStyle(
                    fontSize: 30,
                    letterSpacing: letterSpacingMain(10),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 36),
                _login(),
                SizedBox(height: 24),
                _register(),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langButton('EN', const Locale('en')),
          const Text("  |  ", style: TextStyle(color: Colors.white)),
          _langButton('ລາວ', const Locale('lo')),
        ],
      ),
    );
  }

  Widget _langButton(String label, Locale locale) {
    return InkWell(
      onTap: () {
        // print('[$label] clicked! changing locale to ${locale.languageCode}');
        appLocale.value = locale;
      },
      onHover: (hovering) {
        //print('[$label] hover: $hovering');
      },
      hoverColor: Colors.white24,
      splashColor: Colors.white38,
      highlightColor: Colors.white30,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _login() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: ElevatedButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: const Loginpage(),
                ),
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 60),
          side: const BorderSide(color: Colors.white, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          l10nOf(context).signIn,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _register() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: ElevatedButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: const Signuppage(),
                ),
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          l10nOf(context).signUp,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
