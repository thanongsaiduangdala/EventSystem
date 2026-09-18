import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/LogSignPage/ForgotPasswordPage.dart';
import 'package:ticket_com/MainPage/mainpage.dart';
import 'package:ticket_com/main.dart';
import 'package:ticket_com/services/auth_service.dart';

const Color kAuthPageBackground = Color(0xFFCFE8F7);
const Color kAuthBrandBlue = Color(0xFF6FC3EA);
const Color kAuthBrandBlueDeep = Color(0xFF2F8FBF);
const Color kAuthDarkNavy = Color(0xFF16324A);
const Color kAuthNearBlack = Color(0xFF1C1C1C);

enum _AuthStage { welcome, login, signup, otp }

class Mainloginsignup extends StatefulWidget {
  const Mainloginsignup({super.key});

  @override
  State<Mainloginsignup> createState() => _MainloginsignupState();
}

class _MainloginsignupState extends State<Mainloginsignup>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _blobOut;
  late final Animation<double> _loaderFade;
  late final Animation<double> _logoUp;
  late final Animation<double> _panelUp;
  late final Animation<double> _buttonsUp;

  late final AnimationController _viewCtrl;
  _AuthStage _stage = _AuthStage.welcome;
  _AuthStage _nextStage = _AuthStage.welcome;

  final TextEditingController _email = TextEditingController();
  final TextEditingController _pwd = TextEditingController();
  bool _showPwd = true;
  bool _rememberMe = false;
  bool _emailErr = false;
  bool _pwdErr = false;
  String _emailErrText = '';
  String _pwdErrText = '';
  bool _loginBusy = false;

  final TextEditingController _first = TextEditingController();
  final TextEditingController _last = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _suEmail = TextEditingController();
  final TextEditingController _suPwd = TextEditingController();
  final TextEditingController _confirmPwd = TextEditingController();
  bool _showSuPwd = true;
  bool _showConfirmPwd = true;
  bool _suFirstErr = false;
  bool _suLastErr = false;
  bool _suPhoneErr = false;
  bool _suEmailErr = false;
  bool _suPwdErr = false;
  bool _suConfirmErr = false;
  bool _emailDup = false;
  bool _phoneDup = false;
  bool _sendingOtp = false;

  final TextEditingController _otp = TextEditingController();
  bool _otpErr = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _blobOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.35, curve: Curves.easeInOut),
    );
    _loaderFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _logoUp = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.60, curve: Curves.easeOutCubic),
    );
    _panelUp = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.80, curve: Curves.easeOutCubic),
    );
    _buttonsUp = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 0.95, curve: Curves.easeOutCubic),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _controller.forward();
    });

    _viewCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _viewCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _stage = _nextStage);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _viewCtrl.dispose();
    _email.dispose();
    _pwd.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _suEmail.dispose();
    _suPwd.dispose();
    _confirmPwd.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthPageBackground,
      body: _body(),
    );
  }

  Widget _body() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _animatedCard(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
      },
    );
  }

  Widget _animatedCard({required double width, required double height}) {
    final double topBlob = (width * 0.36).clamp(80.0, 300.0).toDouble();
    final double bottomBlob = (width * 0.56).clamp(140.0, 420.0).toDouble();
    final double welcomePanelHeight =
        (height * 0.53).clamp(330.0, double.infinity).toDouble();
    final double formPanelHeight =
        (height * 0.85).clamp(460.0, double.infinity).toDouble();
    final double panelRise = (height * 0.14).clamp(90.0, 160.0).toDouble();

    const double logoHalf = 78;
    final double requiredRaise = (welcomePanelHeight - height / 2 + logoHalf)
        .clamp(0.0, double.infinity)
        .toDouble();
    final double logoRaise =
        math.max(height * 0.27, requiredRaise).clamp(0.0, height * 0.45).toDouble();

    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(color: Colors.white),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          _cornerBlob(
            alignment: Alignment.topRight,
            size: Size(topBlob, topBlob),
            radius: BorderRadius.only(bottomLeft: Radius.circular(topBlob)),
            slide: Offset(topBlob * 0.6, -topBlob * 0.6),
          ),
          _cornerBlob(
            alignment: Alignment.bottomLeft,
            size: Size(bottomBlob, bottomBlob),
            radius: BorderRadius.only(topRight: Radius.circular(bottomBlob)),
            slide: Offset(-bottomBlob * 0.5, bottomBlob * 0.5),
          ),
          _splashLogo(raise: logoRaise),
          _bottomPanel(
            welcomeHeight: welcomePanelHeight,
            formHeight: formPanelHeight,
            riseStart: panelRise,
          ),
        ],
      ),
    );
  }

  Widget _cornerBlob({
    required Alignment alignment,
    required Size size,
    required BorderRadius radius,
    required Offset slide,
  }) {
    return Positioned(
      top: alignment == Alignment.topRight ? 0 : null,
      right: alignment == Alignment.topRight ? 0 : null,
      left: alignment == Alignment.bottomLeft ? 0 : null,
      bottom: alignment == Alignment.bottomLeft ? 0 : null,
      child: AnimatedBuilder(
        animation: _blobOut,
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: kAuthBrandBlue,
            borderRadius: radius,
          ),
        ),
        builder: (context, child) {
          final double t = _blobOut.value;
          return Opacity(
            opacity: 1 - t,
            child: Transform.translate(
              offset: Offset(slide.dx * t, slide.dy * t),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _splashLogo({required double raise}) {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoUp, _viewCtrl, _loaderFade]),
      builder: (context, child) {
        final double logo = _logoUp.value;
        final double v = _viewCtrl.value;
        final bool outForm = _stage != _AuthStage.welcome;
        final bool inForm = _nextStage != _AuthStage.welcome;
        final double formAmount =
            (outForm ? 1.0 : 0.0) + ((inForm ? 1.0 : 0.0) - (outForm ? 1.0 : 0.0)) * v;

        Widget welcomeLockup = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.chair, size: 64, color: kAuthBrandBlueDeep),
            const SizedBox(height: 14),
            _brandLockup(fontSize: 26),
            const SizedBox(height: 18),
            Opacity(
              opacity: (1 - _loaderFade.value).clamp(0.0, 1.0),
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: kAuthBrandBlueDeep,
                ),
              ),
            ),
          ],
        );

        welcomeLockup = Transform.translate(
          offset: Offset(0, -raise * logo),
          child: Transform.scale(
            scale: 1 - 0.05 * logo,
            child: welcomeLockup,
          ),
        );

        return Stack(
          children: [
            Center(
              child: Opacity(
                opacity: (1 - formAmount).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -24 * formAmount),
                  child: welcomeLockup,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 18,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: formAmount.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - formAmount)),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Symbols.chair,
                          size: 26,
                          color: kAuthBrandBlueDeep,
                        ),
                        const SizedBox(width: 10),
                        _brandLockup(fontSize: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _brandLockup({required double fontSize}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
        ),
        children: const [
          TextSpan(
            text: 'Ticket',
            style: TextStyle(color: kAuthNearBlack),
          ),
          TextSpan(
            text: '.com',
            style: TextStyle(color: kAuthBrandBlueDeep),
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel({
    required double welcomeHeight,
    required double formHeight,
    required double riseStart,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([_viewCtrl, _panelUp]),
      builder: (context, child) {
        final double v = _viewCtrl.value;
        final bool outForm = _stage != _AuthStage.welcome;
        final bool inForm = _nextStage != _AuthStage.welcome;
        final double outF = outForm ? formHeight : welcomeHeight;
        final double inF = inForm ? formHeight : welcomeHeight;
        final double panelHeight = outF + (inF - outF) * v;
        final double t = _panelUp.value;

        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: panelHeight,
          child: Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * riseStart),
              child: Container(
                decoration: const BoxDecoration(
                  color: kAuthBrandBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(36),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _panelBody(panelHeight: panelHeight),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _panelBody({required double panelHeight}) {
    if (_viewCtrl.isAnimating) {
      final double v = _viewCtrl.value;
      final bool inPhase = v >= 0.5;
      final double p = inPhase ? (v - 0.5) * 2 : (1 - v * 2);
      final Widget child = _stageWidget(inPhase ? _nextStage : _stage);
      final double slide = inPhase ? (1 - p) : -p;
      return Transform.translate(
        offset: Offset(0, slide * panelHeight),
        child: Opacity(opacity: p.clamp(0.0, 1.0), child: child),
      );
    }
    return _stageWidget(_stage);
  }

  Widget _stageWidget(_AuthStage stage) {
    switch (stage) {
      case _AuthStage.welcome:
        return _welcomeContent();
      case _AuthStage.login:
        return _loginContent();
      case _AuthStage.signup:
        return _signUpContent();
      case _AuthStage.otp:
        return _otpContent();
    }
  }

  void _goTo(_AuthStage next) {
    if (_viewCtrl.isAnimating) return;
    if (_stage == next) return;
    setState(() => _nextStage = next);
    _viewCtrl.forward(from: 0);
  }

  // ------------------------------ Welcome ------------------------------

  Widget _welcomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10nOf(context).welcome,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: letterSpacingMain(1),
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Discover and book tickets for events near you. '
          'Sign in or create an account to get started.',
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: Color(0xD9FFFFFF),
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
        AnimatedBuilder(
          animation: _buttonsUp,
          child: Row(
            children: [
              _actionButton(
                background: kAuthDarkNavy,
                foreground: Colors.white,
                onPressed: () => _goTo(_AuthStage.login),
                label: l10nOf(context).signIn,
              ),
              const SizedBox(width: 12),
              _actionButton(
                background: Colors.white,
                foreground: kAuthBrandBlueDeep,
                onPressed: () => _goTo(_AuthStage.signup),
                label: l10nOf(context).signUp,
              ),
            ],
          ),
          builder: (context, child) {
            final double t = _buttonsUp.value;
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 30),
                child: child,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _actionButton({
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: const StadiumBorder(),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: letterSpacingMain(1),
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------ Login ------------------------------

  Widget _loginContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formHeader(
            title: l10nOf(context).login,
            onBack: () => _goTo(_AuthStage.welcome),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 18),
            child: Text(
              'Sign in to your account to manage tickets.',
              style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xD9FFFFFF)),
            ),
          ),
          _authField(
            controller: _email,
            label: l10nOf(context).email,
            keyboardType: TextInputType.emailAddress,
            icon: Icons.mail_outline,
            error: _emailErr,
            errorText: _emailErr ? _emailErrText : null,
            onChange: () => setState(() {
              _emailErr = false;
              _emailErrText = '';
            }),
          ),
          const SizedBox(height: 14),
          _authField(
            controller: _pwd,
            label: l10nOf(context).password,
            icon: Icons.lock_outline,
            obscure: _showPwd,
            error: _pwdErr,
            errorText: _pwdErr ? _pwdErrText : null,
            onChange: () => setState(() {
              _pwdErr = false;
              _pwdErrText = '';
            }),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => setState(() => _showPwd = !_showPwd),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _showPwd ? Icons.visibility : Icons.visibility_off,
                    size: 22,
                    color: kAuthBrandBlueDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: kAuthDarkNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (bool? value) {
                        setState(() => _rememberMe = value ?? false);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Remember me',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _openForgotPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10nOf(context).forgotPassword,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _submitPill(
            label: l10nOf(context).login,
            busy: _loginBusy,
            onPressed: _doLogin,
          ),
          const SizedBox(height: 16),
          Center(
            child: _switchLink(
              prefix: l10nOf(context).dontHaveAccount,
              link: l10nOf(context).signUpLink,
              onTap: () => _goTo(_AuthStage.signup),
            ),
          ),
        ],
      ),
    );
  }

  void _openForgotPassword() {
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: const ForgotPasswordPage(),
          ),
        ),
      ),
    );
  }

  Future<void> _doLogin() async {
    setState(() {
      _emailErr = _email.text.trim().isEmpty;
      _emailErrText = l10nOf(context).dontLeaveEmailEmpt;
      _pwdErr = _pwd.text.trim().isEmpty;
      _pwdErrText = l10nOf(context).dontLeavePasswordEmpt;
    });
    if (_emailErr || _pwdErr) return;

    setState(() => _loginBusy = true);
    try {
      final session = await AuthService.login(_email.text.trim(), _pwd.text);
      await AuthService.saveSession(session, _rememberMe);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Mainpage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('not found')) {
        setState(() {
          _emailErr = true;
          _emailErrText = l10nOf(context).emailNotFound;
        });
      } else if (message.toLowerCase().contains('password') ||
          message.toLowerCase().contains('incorrect')) {
        setState(() {
          _pwdErr = true;
          _pwdErrText = 'Incorrect password';
        });
      } else {
        _showErrorDialog(l10nOf(context).connectionError, message);
      }
    } finally {
      if (mounted) setState(() => _loginBusy = false);
    }
  }

  // ------------------------------ Sign up ------------------------------

  Widget _signUpContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formHeader(
            title: l10nOf(context).signUp,
            onBack: () => _goTo(_AuthStage.welcome),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 18),
            child: Text(
              'Create an account and start booking tickets.',
              style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xD9FFFFFF)),
            ),
          ),
          _authField(
            controller: _first,
            label: l10nOf(context).firstName,
            icon: Icons.person_outline,
            error: _suFirstErr,
            errorText: _suFirstErr ? l10nOf(context).dontLeaveFirstNameEmpty : null,
            onChange: () => setState(() => _suFirstErr = false),
          ),
          const SizedBox(height: 14),
          _authField(
            controller: _last,
            label: l10nOf(context).lastName,
            icon: Icons.person_outline,
            error: _suLastErr,
            errorText: _suLastErr ? l10nOf(context).dontLeaveLastNameEmpty : null,
            onChange: () => setState(() => _suLastErr = false),
          ),
          const SizedBox(height: 14),
          _authField(
            controller: _phone,
            label: l10nOf(context).phoneNumber,
            keyboardType: TextInputType.phone,
            icon: Icons.phone_outlined,
            error: _suPhoneErr || _phoneDup,
            errorText: _suPhoneErr || _phoneDup ? _phoneErrorText() : null,
            onChange: () => setState(() {
              _suPhoneErr = false;
              _phoneDup = false;
            }),
          ),
          const SizedBox(height: 14),
          _authField(
            controller: _suEmail,
            label: l10nOf(context).email,
            keyboardType: TextInputType.emailAddress,
            icon: Icons.mail_outline,
            error: _suEmailErr || _emailDup,
            errorText: _suEmailErr || _emailDup ? _emailErrorText() : null,
            onChange: () => setState(() {
              _suEmailErr = false;
              _emailDup = false;
            }),
          ),
          const SizedBox(height: 14),
          _authField(
            controller: _suPwd,
            label: l10nOf(context).password,
            icon: Icons.lock_outline,
            obscure: _showSuPwd,
            error: _suPwdErr,
            errorText: _suPwdErr ? _pwdErrorText() : null,
            onChange: () => setState(() => _suPwdErr = false),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => setState(() => _showSuPwd = !_showSuPwd),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _showSuPwd ? Icons.visibility : Icons.visibility_off,
                    size: 22,
                    color: kAuthBrandBlueDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _authField(
            controller: _confirmPwd,
            label: l10nOf(context).confirmPassword,
            icon: Icons.lock_outline,
            obscure: _showConfirmPwd,
            error: _suConfirmErr,
            errorText: _suConfirmErr ? _confirmPwdErrorText() : null,
            onChange: () => setState(() => _suConfirmErr = false),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () =>
                      setState(() => _showConfirmPwd = !_showConfirmPwd),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _showConfirmPwd ? Icons.visibility : Icons.visibility_off,
                    size: 22,
                    color: kAuthBrandBlueDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _submitPill(
            label: l10nOf(context).signUp,
            busy: _sendingOtp,
            white: true,
            onPressed: _beginSignUp,
          ),
          const SizedBox(height: 16),
          Center(
            child: _switchLink(
              prefix: l10nOf(context).alreadyHaveAccount,
              link: l10nOf(context).signInLink,
              onTap: () => _goTo(_AuthStage.login),
            ),
          ),
        ],
      ),
    );
  }

  String _phoneErrorText() {
    if (_phoneDup) return l10nOf(context).phoneAlreadyRegistered;
    return _phone.text.trim().isEmpty
        ? l10nOf(context).dontLeavePhoneEmpty
        : l10nOf(context).phoneMustBeNumbers;
  }

  String _emailErrorText() {
    if (_emailDup) return l10nOf(context).emailAlreadyRegistered;
    return _suEmail.text.trim().isEmpty
        ? l10nOf(context).dontLeaveEmailEmpt
        : l10nOf(context).pleaseEnterValidEmail;
  }

  String _pwdErrorText() {
    return _suPwd.text.trim().isEmpty
        ? l10nOf(context).dontLeavePasswordEmpt
        : l10nOf(context).passwordMustBeAtLeast6Char;
  }

  String _confirmPwdErrorText() {
    return _confirmPwd.text.trim().isEmpty
        ? l10nOf(context).dontLeaveConfirmPasswordEmpty
        : l10nOf(context).passwordsDoNotMatch;
  }

  Future<void> _beginSignUp() async {
    setState(() {
      _suFirstErr = _first.text.trim().isEmpty;
      _suLastErr = _last.text.trim().isEmpty;
      _suPhoneErr = _phone.text.trim().isEmpty ||
          int.tryParse(_phone.text.trim()) == null;
      _suEmailErr = _suEmail.text.trim().isEmpty ||
          !_suEmail.text.contains('@');
      _suPwdErr =
          _suPwd.text.trim().isEmpty || _suPwd.text.length < 6;
      _suConfirmErr = _confirmPwd.text.trim().isEmpty ||
          _suPwd.text != _confirmPwd.text;
    });
    if (_suFirstErr ||
        _suLastErr ||
        _suPhoneErr ||
        _suEmailErr ||
        _suPwdErr ||
        _suConfirmErr) {
      return;
    }

    setState(() => _sendingOtp = true);
    try {
      final dupResponse = await http.post(
        Uri.parse('http://localhost:8000/signup/check-duplicate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _suEmail.text.trim(),
          'phonenum': _phone.text.trim(),
        }),
      );
      if (dupResponse.statusCode != 200) {
        final error = jsonDecode(dupResponse.body);
        final detail = error['detail'].toString();
        setState(() {
          if (detail.contains('CustomerEmail')) {
            _emailDup = true;
          } else if (detail.contains('CustomerPhoneNum')) {
            _phoneDup = true;
          }
        });
        return;
      }

      final otpResponse = await http.post(
        Uri.parse('http://localhost:8000/signup/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _suEmail.text.trim()}),
      );
      if (otpResponse.statusCode == 200) {
        _otp.clear();
        _otpErr = false;
        if (!mounted) return;
        _goTo(_AuthStage.otp);
      } else {
        if (!mounted) return;
        _showErrorDialog(
          l10nOf(context).error,
          'Failed to send verification email. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(l10nOf(context).connectionError, 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.text.trim().isEmpty || _otp.text.trim().length < 6) {
      setState(() => _otpErr = true);
      return;
    }

    setState(() => _verifying = true);
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstname': _first.text,
          'lastname': _last.text,
          'phonenum': _phone.text.trim(),
          'email': _suEmail.text,
          'password': _suPwd.text,
          'otp': _otp.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        snackbarKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(l10nOf(context).accountCreatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        _clearSignUp();
        _goTo(_AuthStage.welcome);
      } else {
        final error = jsonDecode(response.body);
        final detail = error['detail'].toString();
        if (detail.contains('Invalid OTP')) {
          setState(() => _otpErr = true);
        } else if (detail.contains('CustomerEmail')) {
          _suEmail.clear();
          if (!mounted) return;
          setState(() => _emailDup = true);
          _goTo(_AuthStage.signup);
        } else if (detail.contains('CustomerPhoneNum')) {
          _phone.clear();
          if (!mounted) return;
          setState(() => _phoneDup = true);
          _goTo(_AuthStage.signup);
        } else {
          if (!mounted) return;
          _showErrorDialog(
            l10nOf(context).error,
            detail.replaceFirst('Exception: ', ''),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(l10nOf(context).connectionError, 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _clearSignUp() {
    _first.clear();
    _last.clear();
    _phone.clear();
    _suEmail.clear();
    _suPwd.clear();
    _confirmPwd.clear();
    _otp.clear();
    setState(() {
      _suFirstErr = false;
      _suLastErr = false;
      _suPhoneErr = false;
      _suEmailErr = false;
      _suPwdErr = false;
      _suConfirmErr = false;
      _emailDup = false;
      _phoneDup = false;
      _otpErr = false;
    });
  }

  // ------------------------------ OTP ------------------------------

  Widget _otpContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formHeader(
            title: l10nOf(context).checkYourEmail,
            onBack: () => _goTo(_AuthStage.signup),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 20),
            child: Text(
              'We sent a verification code to',
              style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xD9FFFFFF)),
            ),
          ),
          Text(
            _suEmail.text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Can't find it? Check your spam or junk folder.",
                    style: TextStyle(fontSize: 12.5, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: TextField(
                controller: _otp,
                onChanged: (_) => setState(() => _otpErr = false),
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
                  counterText: '',
                  hintText: '------',
                  hintStyle: TextStyle(
                    color: Colors.grey[300],
                    letterSpacing: 12,
                    fontSize: 28,
                  ),
                  errorText: _otpErr ? l10nOf(context).wrongCodeETC : null,
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _otpErr ? Colors.red : Colors.grey[300]!,
                      width: _otpErr ? 2 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _otpErr ? Colors.red : kAuthBrandBlueDeep,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _submitPill(
            label: l10nOf(context).verify,
            busy: _verifying,
            onPressed: _verifyOtp,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _goTo(_AuthStage.signup),
              child: Text(
                l10nOf(context).backToSignUp,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------ Shared ------------------------------

  Widget _formHeader({required String title, required VoidCallback onBack}) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: letterSpacingMain(2),
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _switchLink({
    required String prefix,
    required String link,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          prefix,
          style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            link,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _submitPill({
    required String label,
    required VoidCallback onPressed,
    bool busy = false,
    bool white = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: white ? Colors.white : kAuthDarkNavy,
          foregroundColor: white ? kAuthBrandBlueDeep : Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: const StadiumBorder(),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: letterSpacingMain(2),
                  color: white ? kAuthBrandBlueDeep : Colors.white,
                ),
              ),
      ),
    );
  }

  InputBorder _fieldBorder({required bool error, required bool focused}) {
    const borderColor = Color(0xFFE0E0E0);
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: error ? Colors.red : (focused ? kAuthBrandBlueDeep : borderColor),
        width: error || focused ? 2 : 1,
      ),
    );
  }

  Widget _authField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    bool error = false,
    String? errorText,
    Widget? suffixIcon,
    VoidCallback? onChange,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF212121),
      ),
      onChanged: (_) => onChange?.call(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: error ? Colors.red : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        errorText: error ? errorText : null,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: suffixIcon,
        enabledBorder: _fieldBorder(error: error, focused: false),
        focusedBorder: _fieldBorder(error: error, focused: true),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10nOf(context).ok),
          ),
        ],
      ),
    );
  }
}