// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'EduConnect';

  @override
  String get login => 'Se connecter';

  @override
  String get register => 'S\'inscrire';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mot de passe';

  @override
  String get phone => 'Téléphone';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get wilaya => 'Wilaya';

  @override
  String get teacher => 'Enseignant';

  @override
  String get parent => 'Parent';

  @override
  String get student => 'Élève';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get alreadyHaveAccount => 'Déjà un compte ?';

  @override
  String get chooseRole => 'Vous êtes...';

  @override
  String get sessions => 'Sessions';

  @override
  String get courses => 'Cours';

  @override
  String get search => 'Rechercher';

  @override
  String get progress => 'Progression';

  @override
  String get notifications => 'Notifications';

  @override
  String get settings => 'Paramètres';

  @override
  String get logout => 'Déconnexion';

  @override
  String welcome(String name) {
    return 'Bonjour, $name 👋';
  }
}
