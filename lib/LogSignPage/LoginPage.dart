import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:reservation_system/EngLoStyle/eng_lao_style.dart';
import 'package:reservation_system/LogSignPage/ForgotPasswordPage.dart';
import 'package:reservation_system/LogSignPage/SignUpPage.dart';
import 'package:reservation_system/services/auth_service.dart';
import 'package:reservation_system/MainPage/mainpage.dart';
//import 'package:reservation_system/main.dart';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  bool showText = true;
  bool rememberMeValue = false;
  bool _emailError = false;
  bool _passwordError = false;
  String _emailErrorText = "";
  String _passwordErrorText = "";

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _body();
  }

  Widget _body() {
    return Padding(
      padding: EdgeInsets.only(
        left: 40,
        right: 40,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            l10nOf(context).login,
            style: TextStyle(fontSize: 30, letterSpacing: letterSpacingMain(5)),
          ),
          const SizedBox(height: 20),
          _txtEmail(),
          const SizedBox(height: 20),
          _txtPassword(),
          const SizedBox(height: 20),
          _lblRememberMeForgot(),
          const SizedBox(height: 80),
          _btnLogin(),
          const SizedBox(height: 20),
          _signUpText(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void showTextPassword() {
    setState(() => showText = !showText);
  }

  Widget _txtEmail() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      onChanged: (_) => setState(() => _emailError = false),
      decoration: InputDecoration(
        labelText: l10nOf(context).email,
        labelStyle: TextStyle(color: _emailError ? Colors.red : null),
        errorText: _emailError ? _emailErrorText : null,
        enabledBorder: _emailError
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              )
            : const UnderlineInputBorder(),
        focusedBorder: _emailError
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              )
            : const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
        suffixIcon: _emailError
            ? const Icon(Icons.error_outline, color: Colors.red)
            : null,
      ),
    );
  }

  Widget _txtPassword() {
    return TextField(
      controller: _passwordController,
      obscureText: showText,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      onChanged: (_) => setState(() => _passwordError = false),
      decoration: InputDecoration(
        labelText: l10nOf(context).password,
        labelStyle: TextStyle(color: _passwordError ? Colors.red : null),
        errorText: _passwordError ? _passwordErrorText : null,
        enabledBorder: _passwordError
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              )
            : const UnderlineInputBorder(),
        focusedBorder: _passwordError
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              )
            : const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_passwordError)
              const Icon(Icons.error_outline, color: Colors.red),
            IconButton(
              onPressed: showTextPassword,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                showText ? Icons.visibility : Icons.visibility_off,
                size: 30,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lblRememberMeForgot() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: rememberMeValue,
                activeColor: Colors.purple,
                onChanged: (bool? value) {
                  setState(() => rememberMeValue = value ?? false);
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10nOf(context).rememberMe,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
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
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: const ForgotPasswordPage(),
                  ),
                ),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            l10nOf(context).forgotPassword,
            style: const TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _doLogin() async {
    setState(() {
      _emailError = _emailController.text.trim().isEmpty;
      _emailErrorText = "Don't leave email empty";
      _passwordError = _passwordController.text.trim().isEmpty;
      _passwordErrorText = "Don't leave password empty";
    });

    if (_emailError || _passwordError) return;

    try {
      final session = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      await AuthService.saveSession(session, rememberMeValue);

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Mainpage()),
        (route) => false,
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');

      if (message.toLowerCase().contains('not found')) {
        setState(() {
          _emailError = true;
          _emailErrorText = "Email not found";
        });
      } else if (message.toLowerCase().contains('password') ||
          message.toLowerCase().contains('incorrect')) {
        setState(() {
          _passwordError = true;
          _passwordErrorText = "Incorrect password";
        });
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Connection Error"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Color.fromARGB(255, 117, 27, 27)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _btnLogin() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _doLogin,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.fromARGB(255, 182, 61, 61),
                Color.fromARGB(255, 117, 27, 27),
                Color.fromARGB(255, 34, 7, 7),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              l10nOf(context).login,
              style: TextStyle(
                fontSize: 20,
                letterSpacing: letterSpacingMain(5),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _signUpText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          l10nOf(context).dontHaveAccount,
          style: const TextStyle(color: Colors.black54),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
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
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: const Signuppage(),
                  ),
                ),
              ),
            );
          },
          child: Text(
            l10nOf(context).signUpLink,
            style: const TextStyle(
              color: Color.fromARGB(255, 182, 61, 61),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
