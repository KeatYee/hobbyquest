/// Centralized font size and family constants for HobbyQuest.
///
/// Usage:
///   import '../../../core/constants/font_constants.dart';
///   Text('Hello', style: TextStyle(fontSize: AppFonts.titlePage));
///
/// Font hierarchy (largest → smallest):
///   logo       32  – "HOBBY QUEST" branding only
///   titlePage  24  – page hero titles
///   valueLg    22  – large numeric values (XP, stats)
///   titleLg    20  – AppBar titles, section headers
///   title      18  – card titles, prominent labels
///   body       16  – large body, mascot messages
///   button     15  – primary action buttons
///   bodyLg     14  – body text, description, steps
///   caption    13  – subtitles, secondary info, hints
///   badge      12  – pills, chips, media buttons
///   micro      11  – tiny badges, char counters, footnotes
///   label      10  – section labels (ALL CAPS)
class AppFonts {
  AppFonts._();

  static const String familyPrimary = 'OpenSans';

  static const double logo = 32.0;

  static const double titlePage = 24.0;

  static const double valueLg = 22.0;

  static const double titleLg = 20.0;

  static const double title = 18.0;

  static const double body = 16.0;

  static const double button = 15.0;

  static const double bodyLg = 14.0;

  static const double caption = 13.0;

  static const double badge = 12.0;

  static const double micro = 11.0;

  static const double label = 10.0;
}
