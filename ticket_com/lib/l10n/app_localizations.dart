import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_lo.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('lo'),
  ];

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get signUp;

  /// No description provided for @ticketCom.
  ///
  /// In en, this message translates to:
  /// **'Ticket.com'**
  String get ticketCom;

  /// No description provided for @loginPage.
  ///
  /// In en, this message translates to:
  /// **'Login Page'**
  String get loginPage;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get login;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @signUpLink.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpLink;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @signInLink.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInLink;

  /// No description provided for @forgotPassword2.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword2;

  /// No description provided for @enterYourEmailETC.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a verification code.'**
  String get enterYourEmailETC;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'SEND CODE'**
  String get sendCode;

  /// No description provided for @arrowTextBack.
  ///
  /// In en, this message translates to:
  /// **'← Back'**
  String get arrowTextBack;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @weSentAVericationETC.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification code to'**
  String get weSentAVericationETC;

  /// No description provided for @cantFindItETC.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find it? Check your spam or junk folder.'**
  String get cantFindItETC;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'VERIFY'**
  String get verify;

  /// No description provided for @verifyingDot.
  ///
  /// In en, this message translates to:
  /// **'VERIFYING...'**
  String get verifyingDot;

  /// No description provided for @wrongCodeETC.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Please try again.'**
  String get wrongCodeETC;

  /// No description provided for @emailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Email not found'**
  String get emailNotFound;

  /// No description provided for @somethingWentWrongPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrongPleaseTryAgain;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get pleaseEnterValidEmail;

  /// No description provided for @dontLeaveEmailEmpt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t leave email empty'**
  String get dontLeaveEmailEmpt;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordMustBeAtLeast6Char.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMustBeAtLeast6Char;

  /// No description provided for @dontLeavePasswordEmpt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t leave password empty'**
  String get dontLeavePasswordEmpt;

  /// No description provided for @dontLeaveConfirmPasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Don\'t leave confirm password empty'**
  String get dontLeaveConfirmPasswordEmpty;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @enterYourNewPasswordBelow.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password below.'**
  String get enterYourNewPasswordBelow;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'RESET PASSWORD'**
  String get resetPassword;

  /// No description provided for @passwordReset.
  ///
  /// In en, this message translates to:
  /// **'Password Reset'**
  String get passwordReset;

  /// No description provided for @loginNow.
  ///
  /// In en, this message translates to:
  /// **'Login Now'**
  String get loginNow;

  /// No description provided for @passwordResetSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your password has been reset successfully. Please login with your new password.'**
  String get passwordResetSuccessMessage;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionError;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @dontLeaveFirstNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Don\'t leave first name empty'**
  String get dontLeaveFirstNameEmpty;

  /// No description provided for @dontLeaveLastNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Don\'t leave last name empty'**
  String get dontLeaveLastNameEmpty;

  /// No description provided for @dontLeavePhoneEmpty.
  ///
  /// In en, this message translates to:
  /// **'Don\'t leave phone number empty'**
  String get dontLeavePhoneEmpty;

  /// No description provided for @phoneMustBeNumbers.
  ///
  /// In en, this message translates to:
  /// **'Phone number must be numbers only'**
  String get phoneMustBeNumbers;

  /// No description provided for @emailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered'**
  String get emailAlreadyRegistered;

  /// No description provided for @phoneAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already registered'**
  String get phoneAlreadyRegistered;

  /// No description provided for @backToSignUp.
  ///
  /// In en, this message translates to:
  /// **'← Back to Sign Up'**
  String get backToSignUp;

  /// No description provided for @accountCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully!'**
  String get accountCreatedSuccessfully;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @ticket.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get ticket;

  /// No description provided for @wish.
  ///
  /// In en, this message translates to:
  /// **'Wish'**
  String get wish;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @setting.
  ///
  /// In en, this message translates to:
  /// **'setting'**
  String get setting;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @eventinfo.
  ///
  /// In en, this message translates to:
  /// **'Event Info'**
  String get eventinfo;

  /// No description provided for @tickettype.
  ///
  /// In en, this message translates to:
  /// **'Ticket Type Info'**
  String get tickettype;

  /// No description provided for @eventquestioninfo.
  ///
  /// In en, this message translates to:
  /// **'Event Question Info'**
  String get eventquestioninfo;

  /// No description provided for @eventquestiontype.
  ///
  /// In en, this message translates to:
  /// **'Event Question Type'**
  String get eventquestiontype;

  /// No description provided for @eventimageinfo.
  ///
  /// In en, this message translates to:
  /// **'Event Image Info'**
  String get eventimageinfo;

  /// No description provided for @eventsponsorinfo.
  ///
  /// In en, this message translates to:
  /// **'Event Sponsor Info'**
  String get eventsponsorinfo;

  /// No description provided for @eventcategoryinfo.
  ///
  /// In en, this message translates to:
  /// **'Event category Info'**
  String get eventcategoryinfo;

  /// No description provided for @eventorganizerinfo.
  ///
  /// In en, this message translates to:
  /// **'Event Organizer Info'**
  String get eventorganizerinfo;

  /// No description provided for @chooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose location'**
  String get chooseLocation;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// No description provided for @nearYou.
  ///
  /// In en, this message translates to:
  /// **'Nearby Events'**
  String get nearYou;

  /// No description provided for @upcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events'**
  String get upcomingEvents;

  /// No description provided for @interestingForYou.
  ///
  /// In en, this message translates to:
  /// **'Interesting Events'**
  String get interestingForYou;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @noEventsNearYou.
  ///
  /// In en, this message translates to:
  /// **'No events near you yet'**
  String get noEventsNearYou;

  /// No description provided for @noUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events yet'**
  String get noUpcomingEvents;

  /// No description provided for @noInterestingEvents.
  ///
  /// In en, this message translates to:
  /// **'No interesting events right now'**
  String get noInterestingEvents;

  /// No description provided for @mostJoinedEvents.
  ///
  /// In en, this message translates to:
  /// **'Most Joined Events'**
  String get mostJoinedEvents;

  /// No description provided for @noMostJoinedEvents.
  ///
  /// In en, this message translates to:
  /// **'No joined events yet'**
  String get noMostJoinedEvents;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResults;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAll;

  /// No description provided for @noMatchingEvents.
  ///
  /// In en, this message translates to:
  /// **'No events match your search'**
  String get noMatchingEvents;

  /// No description provided for @kmAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} km away'**
  String kmAway(Object distance);

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get upcoming;

  /// No description provided for @pastEvents.
  ///
  /// In en, this message translates to:
  /// **'Past Events'**
  String get pastEvents;

  /// No description provided for @noPastEvents.
  ///
  /// In en, this message translates to:
  /// **'No past events yet'**
  String get noPastEvents;

  /// No description provided for @noTicketsYet.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t bought any tickets yet'**
  String get noTicketsYet;

  /// No description provided for @aboutEvent.
  ///
  /// In en, this message translates to:
  /// **'About this event'**
  String get aboutEvent;

  /// No description provided for @tickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get tickets;

  /// No description provided for @buyTicket.
  ///
  /// In en, this message translates to:
  /// **'Buy Ticket'**
  String get buyTicket;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @attending.
  ///
  /// In en, this message translates to:
  /// **'attending'**
  String get attending;

  /// No description provided for @priceFrom.
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get priceFrom;

  /// No description provided for @noTicketsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tickets available yet'**
  String get noTicketsAvailable;

  /// No description provided for @pleaseLogInToBuy.
  ///
  /// In en, this message translates to:
  /// **'Please log in to buy tickets'**
  String get pleaseLogInToBuy;

  /// No description provided for @selectTicketFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a ticket first'**
  String get selectTicketFirst;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Ticket order placed successfully'**
  String get orderPlaced;

  /// No description provided for @eventDetails.
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get eventDetails;

  /// No description provided for @going.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get going;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @organizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get organizer;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read More'**
  String get readMore;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @paymentProof.
  ///
  /// In en, this message translates to:
  /// **'Payment Proof / Reference'**
  String get paymentProof;

  /// No description provided for @paymentProofHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the transaction ID or reference from your bank transfer'**
  String get paymentProofHint;

  /// No description provided for @dontLeavePaymentProofEmpty.
  ///
  /// In en, this message translates to:
  /// **'Don\'t leave payment proof empty'**
  String get dontLeavePaymentProofEmpty;

  /// No description provided for @attendeeInfo.
  ///
  /// In en, this message translates to:
  /// **'Attendee Information'**
  String get attendeeInfo;

  /// No description provided for @forYourself.
  ///
  /// In en, this message translates to:
  /// **'This ticket is for me'**
  String get forYourself;

  /// No description provided for @confirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get confirmOrder;

  /// No description provided for @ticketSlot.
  ///
  /// In en, this message translates to:
  /// **'Ticket {number} · {type}'**
  String ticketSlot(Object number, Object type);

  /// No description provided for @oneTicketPerPerson.
  ///
  /// In en, this message translates to:
  /// **'One ticket per person'**
  String get oneTicketPerPerson;

  /// No description provided for @oneTicketPerPersonInfo.
  ///
  /// In en, this message translates to:
  /// **'This event only allows one ticket per person. Bring your national ID or passport to the entrance.'**
  String get oneTicketPerPersonInfo;

  /// No description provided for @nationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID / Passport No.'**
  String get nationalId;

  /// No description provided for @nationalIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the number shown on your ID'**
  String get nationalIdHint;

  /// No description provided for @nationalIdRequired.
  ///
  /// In en, this message translates to:
  /// **'National ID or passport number is required'**
  String get nationalIdRequired;

  /// No description provided for @nationalIdRepeated.
  ///
  /// In en, this message translates to:
  /// **'This National ID is already used for another ticket in this order'**
  String get nationalIdRepeated;

  /// No description provided for @nationalIdAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This National ID already has a ticket for this event'**
  String get nationalIdAlreadyUsed;

  /// No description provided for @answerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get answerLabel;

  /// No description provided for @questionRequired.
  ///
  /// In en, this message translates to:
  /// **'This question is required'**
  String get questionRequired;

  /// No description provided for @person.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get person;

  /// No description provided for @ticketPurchased.
  ///
  /// In en, this message translates to:
  /// **'Ticket Purchased'**
  String get ticketPurchased;

  /// No description provided for @myTickets.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get myTickets;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @paymentDate.
  ///
  /// In en, this message translates to:
  /// **'Payment Date'**
  String get paymentDate;

  /// No description provided for @answers.
  ///
  /// In en, this message translates to:
  /// **'Answers'**
  String get answers;

  /// No description provided for @scanQrToEnter.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code at the entrance to check in'**
  String get scanQrToEnter;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'lo'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'lo':
      return AppLocalizationsLo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
