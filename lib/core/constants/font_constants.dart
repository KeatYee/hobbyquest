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

  // ── Font Families ────────────────────────────────────
  // Logo branding — Fredoka
  static const String familyLogo = 'Fredoka';
  // Primary UI font — Open Sans (loaded via google_fonts)
  static const String familyPrimary = 'OpenSans';

  // ── Font Sizes ───────────────────────────────────────
  // Logo / branding
  static const double logo = 32.0;

  // Page-level titles
  static const double titlePage = 24.0;

  // Large numeric values (XP rewards, stats)
  static const double valueLg = 22.0;

  // AppBar titles, prominent section headers
  static const double titleLg = 20.0;

  // Card titles, prominent labels
  static const double title = 18.0;

  // Large body, mascot messages
  static const double body = 16.0;

  // Primary action buttons
  static const double button = 15.0;

  // Body text — descriptions, steps, inputs
  static const double bodyLg = 14.0;

  // Subtitles, secondary info, hints
  static const double caption = 13.0;

  // Pills, chips, badges, small buttons
  static const double badge = 12.0;

  // Tiny badges, char counters, footnotes
  static const double micro = 11.0;

  // Section labels (ALL CAPS), overline
  static const double label = 10.0;

  // ── Letter Spacing ───────────────────────────────────
  static const double letterSpacingLogo = 2.0;
  static const double letterSpacingLabel = 1.8;
  static const double letterSpacingButton = 0.3;
}
