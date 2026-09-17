import 'dart:convert';
//import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/main.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final PageController _pageController = PageController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _emailError = false;
  String _emailErrorText = "";
  bool _otpError = false;
  bool _newPasswordError = false;
  String _newPasswordErrorText = "";
  bool _confirmPasswordError = false;
  String _confirmPasswordErrorText = "";
  bool showNewPassword = true;
  bool showConfirmPassword = true;
  //String _generatedOtp = "";
  bool _isVerifying = false;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  double _letterSpacing(double spacing) {
    return appLocale.value.languageCode == 'lo' ? 0 : spacing;
  }

  Future<void> _goToOtp() async {
    setState(() {
      _emailError = _emailController.text.trim().isEmpty;
      _emailErrorText = l10nOf(context).dontLeavePasswordEmpt;
      if (!_emailError && !_emailController.text.contains('@')) {
        _emailError = true;
        _emailErrorText = l10nOf(context).pleaseEnterValidEmail;
      }
    });

    if (_emailError) return;

    try {
      final response = await http.post(
        Uri.parse("http://localhost:8000/forgot-password/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _emailController.text.trim()}),
      );

      print("Send OTP status: ${response.statusCode}");
      print("Send OTP body: ${response.body}");

      if (response.statusCode == 200) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else if (response.statusCode == 404) {
        setState(() {
          _emailError = true;
          _emailErrorText = l10nOf(context).emailNotFound;
        });
      } else {
        setState(() {
          _emailError = true;
          _emailErrorText = l10nOf(context).somethingWentWrongPleaseTryAgain;
        });
      }
    } catch (e) {
      print("Error: $e");
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10nOf(context).connectionError),
          content: Text("$e"),
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

  Future<void> _goToNewPassword() async {
    setState(() {
      _otpError =
          _otpController.text.trim().isEmpty ||
          _otpController.text.trim().length < 6;
    });

    if (_otpError) return;

    setState(() => _isVerifying = true);
    try {
      final response = await http.post(
        Uri.parse("http://localhost:8000/forgot-password/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "otp": _otpController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        _pageController.animateToPage(
          2,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() => _otpError = true);
      }
    } catch (e) {
      print("Error: $e");
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Connection Error"),
          content: Text("$e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _goBack(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Widget _dragHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _backButton(int targetPage) {
    return TextButton(
      onPressed: () => _goBack(targetPage),
      child: Text(
        l10nOf(context).arrowTextBack,
        style: TextStyle(
          color: Color.fromARGB(255, 182, 61, 61),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _gradientButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
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
              label,
              style: TextStyle(
                fontSize: 20,
                letterSpacing: _letterSpacing(5),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 40,
          right: 40,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            const Icon(
              Icons.lock_reset,
              size: 60,
              color: Color.fromARGB(255, 182, 61, 61),
            ),
            const SizedBox(height: 12),
            Text(
              l10nOf(context).forgotPassword2,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: _letterSpacing(3),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10nOf(context).enterYourEmailETC,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 30),
            TextField(
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
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      )
                    : const UnderlineInputBorder(),
                focusedBorder: _emailError
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      )
                    : const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                suffixIcon: _emailError
                    ? const Icon(Icons.error_outline, color: Colors.red)
                    : null,
              ),
            ),
            const SizedBox(height: 40),
            _gradientButton(l10nOf(context).sendCode, _goToOtp),
            const SizedBox(height: 20),
            _backButton(0),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _otpPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 40,
          right: 40,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            const Icon(
              Icons.email_outlined,
              size: 60,
              color: Color.fromARGB(255, 182, 61, 61),
            ),
            const SizedBox(height: 12),
            Text(
              l10nOf(context).checkYourEmail,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10nOf(context).weSentAVericationETC,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _emailController.text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 117, 27, 27),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10nOf(context).cantFindItETC,
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              onChanged: (_) => setState(() => _otpError = false),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
              ),
              decoration: InputDecoration(
                counterText: "",
                hintText: "------",
                hintStyle: TextStyle(
                  color: Colors.grey[300],
                  letterSpacing: 12,
                  fontSize: 28,
                ),
                errorText: _otpError ? l10nOf(context).wrongCodeETC : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _otpError ? Colors.red : Colors.grey,
                    width: _otpError ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _otpError
                        ? Colors.red
                        : const Color.fromARGB(255, 182, 61, 61),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            _gradientButton(
              _isVerifying
                  ? l10nOf(context).verifyingDot
                  : l10nOf(context).verify,
              _isVerifying ? () {} : _goToNewPassword,
            ),
            const SizedBox(height: 20),
            _backButton(0),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _newPasswordPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 40,
          right: 40,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            const Icon(
              Icons.lock_outline,
              size: 60,
              color: Color.fromARGB(255, 182, 61, 61),
            ),
            const SizedBox(height: 12),
            Text(
              l10nOf(context).newPassword,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10nOf(context).enterYourNewPasswordBelow,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _newPasswordController,
              obscureText: showNewPassword,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              onChanged: (_) => setState(() => _newPasswordError = false),
              decoration: InputDecoration(
                labelText: l10nOf(context).newPassword,
                labelStyle: TextStyle(
                  color: _newPasswordError ? Colors.red : null,
                ),
                errorText: _newPasswordError ? _newPasswordErrorText : null,
                enabledBorder: _newPasswordError
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      )
                    : const UnderlineInputBorder(),
                focusedBorder: _newPasswordError
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
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
                    if (_newPasswordError)
                      const Icon(Icons.error_outline, color: Colors.red),
                    IconButton(
                      onPressed: () =>
                          setState(() => showNewPassword = !showNewPassword),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        showNewPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 30,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmPasswordController,
              obscureText: showConfirmPassword,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              onChanged: (_) => setState(() => _confirmPasswordError = false),
              decoration: InputDecoration(
                labelText: l10nOf(context).confirmNewPassword,
                labelStyle: TextStyle(
                  color: _confirmPasswordError ? Colors.red : null,
                ),
                errorText: _confirmPasswordError
                    ? _confirmPasswordErrorText
                    : null,
                enabledBorder: _confirmPasswordError
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      )
                    : const UnderlineInputBorder(),
                focusedBorder: _confirmPasswordError
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
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
                    if (_confirmPasswordError)
                      const Icon(Icons.error_outline, color: Colors.red),
                    IconButton(
                      onPressed: () => setState(
                        () => showConfirmPassword = !showConfirmPassword,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        showConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 30,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            _gradientButton(l10nOf(context).resetPassword, _doResetPassword),
            const SizedBox(height: 20),
            _backButton(1),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _doResetPassword() async {
    setState(() {
      _newPasswordError =
          _newPasswordController.text.trim().isEmpty ||
          _newPasswordController.text.length < 6;
      _newPasswordErrorText = _newPasswordController.text.trim().isEmpty
          ? l10nOf(context).dontLeaveEmailEmpt
          : l10nOf(context).passwordMustBeAtLeast6Char;

      _confirmPasswordError =
          _confirmPasswordController.text.trim().isEmpty ||
          _newPasswordController.text != _confirmPasswordController.text;
      _confirmPasswordErrorText = _confirmPasswordController.text.trim().isEmpty
          ? l10nOf(context).dontLeaveConfirmPasswordEmpty
          : l10nOf(context).passwordsDoNotMatch;
    });

    if (_newPasswordError || _confirmPasswordError) return;

    try {
      final response = await http.post(
        Uri.parse("http://localhost:8000/forgot-password/reset"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "otp": _otpController.text.trim(),
          "new_password": _newPasswordController.text,
        }),
      );

      print("Reset status: ${response.statusCode}");
      print("Reset body: ${response.body}");

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text(l10nOf(context).passwordReset),
              ],
            ),
            content: Text(l10nOf(context).passwordResetSuccessMessage),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(l10nOf(context).loginNow),
              ),
            ],
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        print("Reset failed: $error");
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text(l10nOf(context).error),
              ],
            ),
            content: Text(error['detail'].toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Connection Error"),
          content: Text("$e"),
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_emailPage(), _otpPage(), _newPasswordPage()],
      ),
    );
  }
}
