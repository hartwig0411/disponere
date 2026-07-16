/// Vorlage für `google_config.dart`.
///
/// Die echte Datei ist **git-ignoriert** — das Repo ist öffentlich. Zum
/// Einrichten diese Datei nach `lib/config/google_config.dart` kopieren und
/// die Werte aus der Google Cloud Console eintragen:
/// APIs und Dienste → Anmeldedaten → OAuth-Client vom Typ **Android**.
///
/// Ein Client-**Secret** gibt es beim Android-Typ nicht — PKCE ersetzt es.
class GoogleConfig {
  /// Format: `NNNNNNNNNNNN-xxxxxxxxxxxx.apps.googleusercontent.com`
  static const clientId = 'DEINE-CLIENT-ID.apps.googleusercontent.com';

  /// Umgedrehte Client-ID: `com.googleusercontent.apps.` + Client-ID **ohne**
  /// das Suffix `.apps.googleusercontent.com`.
  ///
  /// Muss **zeichengleich** zu `appAuthRedirectScheme` in
  /// `android/app/build.gradle.kts` sein — sonst findet der Browser beim
  /// Rücksprung die App nicht.
  static const redirectScheme =
      'com.googleusercontent.apps.DEINE-CLIENT-ID-OHNE-SUFFIX';

  /// Redirect-URI für AppAuth. Ein Slash, nicht zwei — so will es Google
  /// für installierte Apps.
  static const redirectUrl = '$redirectScheme:/oauth2redirect';
}