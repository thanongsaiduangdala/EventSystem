//import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ticket_com/LogSignPage/LoginPage.dart';
import 'package:ticket_com/main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/utils/category_colors.dart';

class Signuppage extends StatefulWidget {
  const Signuppage({super.key});

  @override
  State<Signuppage> createState() => _SignuppageState();
}

class _SignuppageState extends State<Signuppage> {
  bool _firstNameError = false;
  bool _lastNameError = false;
  bool _phoneError = false;
  bool _emailError = false;
  bool _passwordError = false;
  bool _confirmPasswordError = false;
  bool _emailDuplicateError = false;
  bool _phoneDuplicateError = false;
  bool _otpError = false;

  bool showText = true;
  bool showConfirmText = true;
  bool _isSendingOtp = false;

  final PageController _pageController = PageController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _goToConfirmation() async {
    setState(() {
      _firstNameError = _firstNameController.text.trim().isEmpty;
      _lastNameError = _lastNameController.text.trim().isEmpty;
      _phoneError =
          _phoneController.text.trim().isEmpty ||
          int.tryParse(_phoneController.text.trim()) == null;
      _emailError =
          _emailController.text.trim().isEmpty ||
          !_emailController.text.contains('@');
      _passwordError =
          _passwordController.text.trim().isEmpty ||
          _passwordController.text.length < 6;
      _confirmPasswordError =
          _confirmPasswordController.text.trim().isEmpty ||
          _passwordController.text != _confirmPasswordController.text;
    });

    if (_firstNameError ||
        _lastNameError ||
        _phoneError ||
        _emailError ||
        _passwordError ||
        _confirmPasswordError)
      return;

    setState(() => _isSendingOtp = true);
    try {
      final dupResponse = await http.post(
        Uri.parse("http://localhost:8000/signup/check-duplicate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "phonenum": _phoneController.text.trim(),
        }),
      );

      if (dupResponse.statusCode != 200) {
        final error = jsonDecode(dupResponse.body);
        final detail = error['detail'].toString();

        if (detail.contains('CustomerEmail')) {
          setState(() => _emailDuplicateError = true);
        } else if (detail.contains('CustomerPhoneNum')) {
          setState(() => _phoneDuplicateError = true);
        }
        setState(() => _isSendingOtp = false);
        return;
      }
      final otpResponse = await http.post(
        Uri.parse("http://localhost:8000/signup/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _emailController.text.trim()}),
      );

      if (otpResponse.statusCode == 200) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        _showWarning(
          "Failed to send verification email. Please try again.",
          isError: true,
        );
      }
    } catch (e) {
      _showWarning("Connection error: $e", isError: true);
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  void _goBack() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _showWarning(String message, {bool isError = false}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.warning_amber_rounded,
              color: isError ? Colors.red : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_signUpPage(), _confirmationPage()],
      ),
    );
  }

  Widget _signUpPage() {
    return SingleChildScrollView(
      child: Padding(
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
              l10nOf(context).signUp,
              style: TextStyle(
                fontSize: 30,
                letterSpacing: _letterSpacing(5),
                fontWeight: FontWeight.w800,
                color: kAccent,
              ),
            ),
            const SizedBox(height: 24),
            _txtFirstName(),
            const SizedBox(height: 16),
            _txtLastName(),
            const SizedBox(height: 16),
            _txtPhone(),
            const SizedBox(height: 16),
            _txtEmail(),
            const SizedBox(height: 16),
            _txtPassword(),
            const SizedBox(height: 16),
            _txtConfirmPassword(),
            const SizedBox(height: 32),
            _btnSignUp(),
            const SizedBox(height: 16),
            _loginText(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _confirmationPage() {
    return SingleChildScrollView(
      child: Padding(
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
            const SizedBox(height: 20),
            const Icon(Icons.email_outlined, size: 60, color: kAccent),
            const SizedBox(height: 20),
            Text(
              l10nOf(context).pleaseEnterValidEmail,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10nOf(context).weSentAVericationETC,
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _emailController.text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kAccent,
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
              onChanged: (_) => setState(() => _otpError = false),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
                color: Color(0xFF212121),
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
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _otpError ? Colors.red : Colors.grey[300]!,
                    width: _otpError ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _otpError ? Colors.red : kAccent,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  if (_otpController.text.trim().isEmpty ||
                      _otpController.text.trim().length < 6) {
                    setState(() => _otpError = true);
                    return;
                  }

                  print("=== OTP CORRECT, calling signup API ===");
                  try {
                    final response = await http.post(
                      Uri.parse("http://localhost:8000/signup"),
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode({
                        "firstname": _firstNameController.text,
                        "lastname": _lastNameController.text,
                        "phonenum": _phoneController.text.trim(),
                        "email": _emailController.text,
                        "password": _passwordController.text,
                        "otp": _otpController.text.trim(),
                      }),
                    );

                    print("Status: ${response.statusCode}");
                    print("Body: ${response.body}");

                    if (response.statusCode == 201) {
                      final data = jsonDecode(response.body);
                      print("Signup success: $data");
                      Navigator.pop(context);
                      snackbarKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10nOf(context).accountCreatedSuccessfully,
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      final error = jsonDecode(response.body);
                      print("Signup failed: $error");
                      final detail = error['detail'].toString();

                      if (detail.contains('Invalid OTP')) {
                        setState(() => _otpError = true);
                      } else if (detail.contains('CustomerEmail')) {
                        _emailController.clear();
                        setState(() => _emailDuplicateError = true);
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else if (detail.contains('CustomerPhoneNum')) {
                        _phoneController.clear();
                        setState(() => _phoneDuplicateError = true);
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _showWarning(detail, isError: true);
                      }
                    }
                  } catch (e) {
                    print("Error: $e");
                    _showWarning("Connection error: $e", isError: true);
                  }
                },
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
                      l10nOf(context).verify,
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
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _goBack,
              child: Text(
                l10nOf(context).backToSignUp,
                style: const TextStyle(
                  color: kAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  double _letterSpacing(double spacing) {
    return appLocale.value.languageCode == 'lo' ? 0 : spacing;
  }

  InputBorder _fieldBorder({required bool error, required bool focused}) {
    const defaultColor = Color(0xFFE0E0E0);
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: error ? Colors.red : (focused ? kAccent : defaultColor),
        width: error || focused ? 2 : 1,
      ),
    );
  }

  Widget _txtField({
    required TextEditingController controller,
    required String label,
    required TextStyle style,
    bool? error,
    String? errorText,
    TextInputType? keyboardType,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: style,
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: error == true ? Colors.red : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        errorText: error == true ? errorText : null,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: prefixIcon,
        enabledBorder: _fieldBorder(error: error == true, focused: false),
        focusedBorder: _fieldBorder(error: error == true, focused: true),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _txtFirstName() {
    return _txtField(
      controller: _firstNameController,
      label: l10nOf(context).firstName,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF212121),
      ),
      error: _firstNameError,
      errorText: l10nOf(context).dontLeaveFirstNameEmpty,
      prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
      suffixIcon: _firstNameError
          ? const Icon(Icons.error_outline, color: Colors.red)
          : null,
      onChanged: () => setState(() => _firstNameError = false),
    );
  }

  Widget _txtLastName() {
    return _txtField(
      controller: _lastNameController,
      label: l10nOf(context).lastName,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF212121),
      ),
      error: _lastNameError,
      errorText: l10nOf(context).dontLeaveLastNameEmpty,
      prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
      suffixIcon: _lastNameError
          ? const Icon(Icons.error_outline, color: Colors.red)
          : null,
      onChanged: () => setState(() => _lastNameError = false),
    );
  }

  Widget _txtPhone() {
    String? phoneErrorText;
    if (_phoneError) {
      phoneErrorText = _phoneController.text.trim().isEmpty
          ? l10nOf(context).dontLeavePhoneEmpty
          : l10nOf(context).phoneMustBeNumbers;
    }
    if (_phoneDuplicateError) {
      phoneErrorText = l10nOf(context).phoneAlreadyRegistered;
    }
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF212121),
      ),
      onChanged: (_) => setState(() {
        _phoneError = false;
        _phoneDuplicateError = false;
      }),
      decoration: InputDecoration(
        labelText: l10nOf(context).phoneNumber,
        labelStyle: TextStyle(
          color: (_phoneError || _phoneDuplicateError)
              ? Colors.red
              : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        errorText: phoneErrorText,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
        enabledBorder: _fieldBorder(
          error: _phoneError || _phoneDuplicateError,
          focused: false,
        ),
        focusedBorder: _fieldBorder(
          error: _phoneError || _phoneDuplicateError,
          focused: true,
        ),
        suffixIcon: (_phoneError || _phoneDuplicateError)
            ? const Icon(Icons.error_outline, color: Colors.red)
            : null,
      ),
    );
  }

  Widget _txtEmail() {
    String? emailErrorText;
    if (_emailError) {
      emailErrorText = _emailController.text.trim().isEmpty
          ? l10nOf(context).dontLeaveEmailEmpt
          : l10nOf(context).pleaseEnterValidEmail;
    }
    if (_emailDuplicateError) {
      emailErrorText = l10nOf(context).emailAlreadyRegistered;
    }
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF212121),
      ),
      onChanged: (_) => setState(() {
        _emailError = false;
        _emailDuplicateError = false;
      }),
      decoration: InputDecoration(
        labelText: l10nOf(context).email,
        labelStyle: TextStyle(
          color: (_emailError || _emailDuplicateError)
              ? Colors.red
              : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        errorText: emailErrorText,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.mail_outline, color: Colors.grey),
        enabledBorder: _fieldBorder(
          error: _emailError || _emailDuplicateError,
          focused: false,
        ),
        focusedBorder: _fieldBorder(
          error: _emailError || _emailDuplicateError,
          focused: true,
        ),
        suffixIcon: (_emailError || _emailDuplicateError)
            ? const Icon(Icons.error_outline, color: Colors.red)
            : null,
      ),
    );
  }

  Widget _txtPassword() {
    String? passwordErrorText;
    if (_passwordError) {
      passwordErrorText = _passwordController.text.trim().isEmpty
          ? l10nOf(context).dontLeavePasswordEmpt
          : l10nOf(context).passwordMustBeAtLeast6Char;
    }
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
        errorText: passwordErrorText,
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
              onPressed: () => setState(() => showText = !showText),
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

  Widget _txtConfirmPassword() {
    String? confirmErrorText;
    if (_confirmPasswordError) {
      confirmErrorText = _confirmPasswordController.text.trim().isEmpty
          ? l10nOf(context).dontLeaveConfirmPasswordEmpty
          : l10nOf(context).passwordsDoNotMatch;
    }
    return TextField(
      controller: _confirmPasswordController,
      obscureText: showConfirmText,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF212121),
      ),
      onChanged: (_) => setState(() => _confirmPasswordError = false),
      decoration: InputDecoration(
        labelText: l10nOf(context).confirmPassword,
        labelStyle: TextStyle(
          color: _confirmPasswordError ? Colors.red : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        errorText: confirmErrorText,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        enabledBorder: _fieldBorder(
          error: _confirmPasswordError,
          focused: false,
        ),
        focusedBorder: _fieldBorder(
          error: _confirmPasswordError,
          focused: true,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_confirmPasswordError)
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
            IconButton(
              onPressed: () =>
                  setState(() => showConfirmText = !showConfirmText),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                showConfirmText ? Icons.visibility : Icons.visibility_off,
                size: 22,
                color: kAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btnSignUp() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSendingOtp ? null : _goToConfirmation,
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
            child: _isSendingOtp
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    l10nOf(context).signUp,
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: _letterSpacing(5),
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _loginText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          l10nOf(context).alreadyHaveAccount,
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
                    child: const Loginpage(),
                  ),
                ),
              ),
            );
          },
          child: Text(
            l10nOf(context).signInLink,
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