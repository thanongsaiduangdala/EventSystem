import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:reservation_system/LogSignPage/MainLoginSignUp.dart';
import 'package:reservation_system/DeveloperPage/MainPageDashboard.dart';
import 'package:reservation_system/MainPage/mainpage.dart';
import 'package:reservation_system/l10n/app_localizations.dart';
import 'package:reservation_system/services/auth_service.dart';

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));
final GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await AuthService.restoreSession();
  runApp(MyApp(startLoggedIn: session != null));
}

class MyApp extends StatelessWidget {
  final bool startLoggedIn;
  const MyApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, child) {
        return MaterialApp(
          scaffoldMessengerKey: snackbarKey,
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('lo')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: startLoggedIn ? const Mainpage() : const Mainloginsignup(),
        );
      },
    );
  }
}
