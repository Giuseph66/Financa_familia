import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_pt.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('pt')];

  /// No description provided for @appName.
  ///
  /// In pt, this message translates to:
  /// **'Finança'**
  String get appName;

  /// No description provided for @greeting.
  ///
  /// In pt, this message translates to:
  /// **'Bom dia, Jesus'**
  String get greeting;

  /// No description provided for @houseName.
  ///
  /// In pt, this message translates to:
  /// **'Casa Neurelix'**
  String get houseName;

  /// No description provided for @offlineStatus.
  ///
  /// In pt, this message translates to:
  /// **'Offline · dados locais'**
  String get offlineStatus;

  /// No description provided for @month.
  ///
  /// In pt, this message translates to:
  /// **'Agosto 2026'**
  String get month;

  /// No description provided for @balanceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Saldo do mês'**
  String get balanceTitle;

  /// No description provided for @balanceHint.
  ///
  /// In pt, this message translates to:
  /// **'Entradas menos saídas'**
  String get balanceHint;

  /// No description provided for @income.
  ///
  /// In pt, this message translates to:
  /// **'Entradas'**
  String get income;

  /// No description provided for @expenses.
  ///
  /// In pt, this message translates to:
  /// **'Saídas'**
  String get expenses;

  /// No description provided for @vsAverage.
  ///
  /// In pt, this message translates to:
  /// **'vs. média 3 meses'**
  String get vsAverage;

  /// No description provided for @comparisonTitle.
  ///
  /// In pt, this message translates to:
  /// **'Como a casa está andando'**
  String get comparisonTitle;

  /// No description provided for @comparisonSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Despesas comuns, sem cobrança'**
  String get comparisonSubtitle;

  /// No description provided for @budgetTitle.
  ///
  /// In pt, this message translates to:
  /// **'Orçamentos em atenção'**
  String get budgetTitle;

  /// No description provided for @upcomingTitle.
  ///
  /// In pt, this message translates to:
  /// **'Próximas contas'**
  String get upcomingTitle;

  /// No description provided for @recentTitle.
  ///
  /// In pt, this message translates to:
  /// **'Últimos lançamentos'**
  String get recentTitle;

  /// No description provided for @seeAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver tudo'**
  String get seeAll;

  /// No description provided for @accountsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Contas e saldos'**
  String get accountsTitle;

  /// No description provided for @quickAdd.
  ///
  /// In pt, this message translates to:
  /// **'Entrada rápida'**
  String get quickAdd;

  /// No description provided for @save.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get save;

  /// No description provided for @expense.
  ///
  /// In pt, this message translates to:
  /// **'Despesa'**
  String get expense;

  /// No description provided for @revenue.
  ///
  /// In pt, this message translates to:
  /// **'Receita'**
  String get revenue;

  /// No description provided for @transfer.
  ///
  /// In pt, this message translates to:
  /// **'Transferência'**
  String get transfer;

  /// No description provided for @today.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get today;

  /// No description provided for @you.
  ///
  /// In pt, this message translates to:
  /// **'Você'**
  String get you;

  /// No description provided for @more.
  ///
  /// In pt, this message translates to:
  /// **'Mais'**
  String get more;

  /// No description provided for @home.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get home;

  /// No description provided for @transactions.
  ///
  /// In pt, this message translates to:
  /// **'Extrato'**
  String get transactions;

  /// No description provided for @reports.
  ///
  /// In pt, this message translates to:
  /// **'Relatórios'**
  String get reports;

  /// No description provided for @privacyOn.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar valores'**
  String get privacyOn;

  /// No description provided for @privacyOff.
  ///
  /// In pt, this message translates to:
  /// **'Esconder valores'**
  String get privacyOff;

  /// No description provided for @categoryFood.
  ///
  /// In pt, this message translates to:
  /// **'Alimentação'**
  String get categoryFood;

  /// No description provided for @categoryHome.
  ///
  /// In pt, this message translates to:
  /// **'Casa'**
  String get categoryHome;

  /// No description provided for @categoryTransport.
  ///
  /// In pt, this message translates to:
  /// **'Transporte'**
  String get categoryTransport;

  /// No description provided for @categoryHealth.
  ///
  /// In pt, this message translates to:
  /// **'Saúde'**
  String get categoryHealth;

  /// No description provided for @categoryLeisure.
  ///
  /// In pt, this message translates to:
  /// **'Lazer'**
  String get categoryLeisure;

  /// No description provided for @categoryMore.
  ///
  /// In pt, this message translates to:
  /// **'Mais'**
  String get categoryMore;

  /// No description provided for @transactionSaved.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento salvo localmente'**
  String get transactionSaved;

  /// No description provided for @pay.
  ///
  /// In pt, this message translates to:
  /// **'Pagar'**
  String get pay;
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
      <String>['pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
