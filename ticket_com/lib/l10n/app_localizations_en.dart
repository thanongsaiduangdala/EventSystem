// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcome => 'Welcome';

  @override
  String get signIn => 'SIGN IN';

  @override
  String get signUp => 'SIGN UP';

  @override
  String get ticketCom => 'Ticket.com';

  @override
  String get loginPage => 'Login Page';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get login => 'LOGIN';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get signUpLink => 'Sign Up';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get signInLink => 'Sign In';

  @override
  String get forgotPassword2 => 'Forgot Password';

  @override
  String get enterYourEmailETC =>
      'Enter your email and we\'ll send you a verification code.';

  @override
  String get sendCode => 'SEND CODE';

  @override
  String get arrowTextBack => '← Back';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String get weSentAVericationETC => 'We sent a verification code to';

  @override
  String get cantFindItETC => 'Can\'t find it? Check your spam or junk folder.';

  @override
  String get verify => 'VERIFY';

  @override
  String get verifyingDot => 'VERIFYING...';

  @override
  String get wrongCodeETC => 'Wrong code. Please try again.';

  @override
  String get emailNotFound => 'Email not found';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Something went wrong. Please try again.';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email address';

  @override
  String get dontLeaveEmailEmpt => 'Don\'t leave email empty';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordMustBeAtLeast6Char =>
      'Password must be at least 6 characters';

  @override
  String get dontLeavePasswordEmpt => 'Don\'t leave password empty';

  @override
  String get dontLeaveConfirmPasswordEmpty =>
      'Don\'t leave confirm password empty';

  @override
  String get newPassword => 'New Password';

  @override
  String get enterYourNewPasswordBelow => 'Enter your new password below.';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get resetPassword => 'RESET PASSWORD';

  @override
  String get passwordReset => 'Password Reset';

  @override
  String get loginNow => 'Login Now';

  @override
  String get passwordResetSuccessMessage =>
      'Your password has been reset successfully. Please login with your new password.';

  @override
  String get connectionError => 'Connection Error';

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get dontLeaveFirstNameEmpty => 'Don\'t leave first name empty';

  @override
  String get dontLeaveLastNameEmpty => 'Don\'t leave last name empty';

  @override
  String get dontLeavePhoneEmpty => 'Don\'t leave phone number empty';

  @override
  String get phoneMustBeNumbers => 'Phone number must be numbers only';

  @override
  String get emailAlreadyRegistered => 'This email is already registered';

  @override
  String get phoneAlreadyRegistered =>
      'This phone number is already registered';

  @override
  String get backToSignUp => '← Back to Sign Up';

  @override
  String get accountCreatedSuccessfully => 'Account created successfully!';

  @override
  String get home => 'Home';

  @override
  String get ticket => 'Ticket';

  @override
  String get wish => 'Wish';

  @override
  String get account => 'Account';

  @override
  String get setting => 'setting';

  @override
  String get map => 'Map';

  @override
  String get eventinfo => 'Event Info';

  @override
  String get tickettype => 'Ticket Type Info';

  @override
  String get eventquestioninfo => 'Event Question Info';

  @override
  String get eventquestiontype => 'Event Question Type';

  @override
  String get eventimageinfo => 'Event Image Info';

  @override
  String get eventsponsorinfo => 'Event Sponsor Info';

  @override
  String get eventcategoryinfo => 'Event category Info';

  @override
  String get eventorganizerinfo => 'Event Organizer Info';

  @override
  String get categories => 'Categories';

  @override
  String get chooseLocation => 'Choose location';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get nearYou => 'Nearby Events';

  @override
  String get upcomingEvents => 'Upcoming Events';

  @override
  String get interestingForYou => 'Interesting Events';

  @override
  String get seeAll => 'See All';

  @override
  String get searchHint => 'Search...';

  @override
  String get filters => 'Filters';

  @override
  String get noEventsNearYou => 'No events near you yet';

  @override
  String get noUpcomingEvents => 'No upcoming events yet';

  @override
  String get noInterestingEvents => 'No interesting events right now';

  @override
  String get mostJoinedEvents => 'Most Joined Events';

  @override
  String get noMostJoinedEvents => 'No joined events yet';

  @override
  String get searchResults => 'Search Results';

  @override
  String get clearAll => 'Clear';

  @override
  String get noMatchingEvents => 'No events match your search';

  @override
  String kmAway(Object distance) {
    return '$distance km away';
  }

  @override
  String get upcoming => 'UPCOMING';

  @override
  String get pastEvents => 'Past Events';

  @override
  String get noPastEvents => 'No past events yet';

  @override
  String get noTicketsYet => 'You haven\'t bought any tickets yet';

  @override
  String get aboutEvent => 'About this event';

  @override
  String get tickets => 'Tickets';

  @override
  String get buyTicket => 'Buy Ticket';

  @override
  String get total => 'Total';

  @override
  String get attending => 'attending';

  @override
  String get priceFrom => 'from';

  @override
  String get noTicketsAvailable => 'No tickets available yet';

  @override
  String get pleaseLogInToBuy => 'Please log in to buy tickets';

  @override
  String get selectTicketFirst => 'Please select a ticket first';

  @override
  String get orderPlaced => 'Ticket order placed successfully';

  @override
  String get eventDetails => 'Event Details';

  @override
  String get going => 'Going';

  @override
  String get invite => 'Invite';

  @override
  String get organizer => 'Organizer';

  @override
  String get follow => 'Follow';

  @override
  String get readMore => 'Read More';

  @override
  String get checkout => 'Checkout';

  @override
  String get orderSummary => 'Order Summary';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get paymentProof => 'Payment Proof / Reference';

  @override
  String get paymentProofHint =>
      'Enter the transaction ID or reference from your bank transfer';

  @override
  String get dontLeavePaymentProofEmpty => 'Don\'t leave payment proof empty';

  @override
  String get attendeeInfo => 'Attendee Information';

  @override
  String get forYourself => 'This ticket is for me';

  @override
  String get confirmOrder => 'Confirm Order';

  @override
  String ticketSlot(Object number, Object type) {
    return 'Ticket $number · $type';
  }

  @override
  String get oneTicketPerPerson => 'One ticket per person';

  @override
  String get oneTicketPerPersonInfo =>
      'This event only allows one ticket per person. Bring your national ID or passport to the entrance.';

  @override
  String get nationalId => 'National ID / Passport No.';

  @override
  String get nationalIdHint => 'Enter the number shown on your ID';

  @override
  String get nationalIdRequired => 'National ID or passport number is required';

  @override
  String get nationalIdRepeated =>
      'This National ID is already used for another ticket in this order';

  @override
  String get nationalIdAlreadyUsed =>
      'This National ID already has a ticket for this event';

  @override
  String get answerLabel => 'Your answer';

  @override
  String get questionRequired => 'This question is required';

  @override
  String get person => 'Person';

  @override
  String get ticketPurchased => 'Ticket Purchased';

  @override
  String get myTickets => 'My Tickets';

  @override
  String get order => 'Order';

  @override
  String get paymentDate => 'Payment Date';

  @override
  String get answers => 'Answers';

  @override
  String get scanQrToEnter => 'Scan this QR code at the entrance to check in';

  @override
  String get following => 'Following';

  @override
  String get followedEvents => 'Followed Events';

  @override
  String get followedOrganizer => 'Organizer followed';

  @override
  String get unfollowedOrganizer => 'Unfollowed organizer';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get lao => 'Lao';

  @override
  String get myProfile => 'My Profile';

  @override
  String get notification => 'Notification';

  @override
  String get calender => 'Calender';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get settings => 'Settings';

  @override
  String get helpsAndFaqs => 'Helps & FAQs';

  @override
  String get signOut => 'Sign Out';

  @override
  String get comingSoon => 'Coming soon';
}
