// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'EduConnect';

  @override
  String get login => 'Sign in';

  @override
  String get register => 'Sign up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get phone => 'Phone';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get wilaya => 'Wilaya';

  @override
  String get teacher => 'Teacher';

  @override
  String get parent => 'Parent';

  @override
  String get student => 'Student';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get createAccount => 'Create an account';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get chooseRole => 'You are...';

  @override
  String get sessions => 'Sessions';

  @override
  String get courses => 'Courses';

  @override
  String get search => 'Search';

  @override
  String get progress => 'Progress';

  @override
  String get notifications => 'Notifications';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Sign out';

  @override
  String welcome(String name) {
    return 'Hello, $name 👋';
  }
}
