//import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/LogSignPage/ForgotPasswordPage.dart';
import 'package:ticket_com/LogSignPage/SignUpPage.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/MainPage/mainpage.dart';
import 'package:ticket_com/utils/category_colors.dart';
//import 'package:ticket_com/main.dart';

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
        left: 24,
        right: 24,
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
            style: TextStyle(
              fontSize: 30,
              letterSpacing: letterSpacingMain(5),
              fontWeight: FontWeight.w800,
              color: kAccent,
            ),
          ),
          const SizedBox(height: 24),
          _txtEmail(),
          const SizedBox(height: 16),
          _txtPassword(),
          const SizedBox(height: 16),
          _lblRememberMeForgot(),
          const SizedBox(height: 32),
          _btnLogin(),
          const SizedBox(height: 16),
          _signUpText(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void showTextPassword() {
    setState(() => showText = !showText);
  }

  InputBorder _fieldBorder({required bool error, required bool focused}) {
    const defaultColor = Color(0xFFE0E0E0);
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: error
            ? Colors.red
            : (focused ? kAccent : defaultColor),
        width: error || focused ? 2 : 1,
      ),
    );
  }

  Widget _txtEmail() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF212121),
      ),
      onChanged: (_) => setState(() => _emailError = false),
      decoration: InputDecoration(
        labelText: l10nOf(context).email,
        labelStyle: TextStyle(
          color: _emailError ? Colors.red : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        errorText: _emailError ? _emailErrorText : null,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.mail_outline, color: Colors.grey),
        enabledBorder: _fieldBorder(error: _emailError, focused: false),
        focusedBorder: _fieldBorder(error: _emailError, focused: true),
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
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF212121),
      ),
      onChanged: (_) => setState(() => _passwordError = false),
      decoration: InputDecoration(
        labelText: l10nOf(context).password,
        labelStyle: TextStyle(
          color: _passwordError ? Colors.red : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        errorText: _passwordError ? _passwordErrorText : null,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        enabledBorder: _fieldBorder(error: _passwordError, focused: false),
        focusedBorder: _fieldBorder(error: _passwordError, focused: true),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_passwordError)
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
            IconButton(
              onPressed: showTextPassword,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                showText ? Icons.visibility : Icons.visibility_off,
                size: 22,
                color: kAccent,
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
                activeColor: kAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
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
                    color: Color(0xFFF5F6FA),
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
              color: kAccent,
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

  Widget _btnLogin() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _doLogin,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [kAccent, Color(0xFF8E2DE2)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x335B4DFF),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              l10nOf(context).login,
              style: TextStyle(
                fontSize: 18,
                letterSpacing: letterSpacingMain(5),
                color: Colors.white,
                fontWeight: FontWeight.w800,
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
                    color: Color(0xFFF5F6FA),
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
              color: kAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}