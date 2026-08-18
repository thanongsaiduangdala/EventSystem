import 'package:flutter/material.dart';
import 'package:ticket_com/l10n/app_localizations.dart';
import 'package:ticket_com/main.dart';

AppLocalizations l10nOf(BuildContext context) {
  return AppLocalizations.of(context)!;
}

double letterSpacingMain(double spacing) {
  return appLocale.value.languageCode == 'lo' ? 0 : spacing;
}
