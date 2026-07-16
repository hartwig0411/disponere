import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/google_config.dart';

/// Fehler aus dem Auth-Weg, in Klartext für die UI.
class GoogleAuthException implements Exception {
  final String message;
  const GoogleAuthException(this.message);

  @override
  String toString() => message;
}

/// GMS-freier OAuth gegen Google — Authorization Code + **PKCE** über AppAuth
/// (System-Browser / Custom Tab). Bewusst **kein** `google_sign_in`: das
/// braucht Play Services, die es auf dem MatePad nicht gibt.
///
/// Siehe `docs/disponere_architektur_google_calendar_v1_0.md` §2, §3 (#1, #5), §9.
///
/// Ablage: Das **Refresh-Token** liegt in `flutter_secure_storage`
/// (Android-Keystore), **nicht** in SQLite oder Prefs. Das Access-Token wird
/// nur im Speicher gehalten und bei Bedarf still erneuert — es hält ca. eine
/// Stunde, ein Neustart holt sich einfach ein frisches.
class GoogleAuthService {
  /// Read-only (Architektur §3 #2) — der Datenfluss ist einseitig
  /// Kalender → Journal.
  static const _scopes = ['https://www.googleapis.com/auth/calendar.readonly'];

  static const _refreshTokenKey = 'google_refresh_token';

  /// Endpunkte fest verdrahtet statt per Discovery-Dokument: spart beim Login
  /// einen Rundlauf und einen möglichen Fehlerfall.
  static const _serviceConfig = AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
  );

  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _accessToken;
  DateTime? _accessTokenExpiry;

  /// Ist ein Konto verbunden? Prüft nur, ob ein Refresh-Token im Keystore
  /// liegt — ohne Netz.
  Future<bool> isSignedIn() async {
    final token = await _storage.read(key: _refreshTokenKey);
    return token != null;
  }

  /// Öffnet den Browser-Login und tauscht den Code gegen Tokens.
  ///
  /// `access_type=offline` ist die Bedingung dafür, dass Google überhaupt ein
  /// Refresh-Token herausgibt — ein Google-eigener Parameter, der über
  /// `additionalParameters` mitfährt.
  ///
  /// `prompt=consent` erzwingt das Refresh-Token auch bei einer **erneuten**
  /// Anmeldung; ohne das liefert Google nur beim allerersten Mal eins. Es geht
  /// über das eigene Feld `promptValues` — `prompt` ist in AppAuth ein
  /// eingebauter Parameter und wird in `additionalParameters` abgewiesen.
  Future<void> signIn() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        GoogleConfig.clientId,
        GoogleConfig.redirectUrl,
        serviceConfiguration: _serviceConfig,
        scopes: _scopes,
        promptValues: const ['consent'],
        additionalParameters: const {'access_type': 'offline'},
      ),
    );
    await _store(result, requireRefreshToken: true);
  }

  /// Trennt das Konto lokal: Refresh-Token weg, Cache leer.
  ///
  /// Der Zugriff bleibt in deinem Google-Konto weiter eingetragen
  /// (myaccount.google.com → Sicherheit → Drittanbieter-Apps); das
  /// serverseitige Widerrufen ist bewusst nicht v1.0.
  Future<void> signOut() async {
    await _storage.delete(key: _refreshTokenKey);
    _accessToken = null;
    _accessTokenExpiry = null;
  }

  /// Ein gültiges Access-Token. Nutzt das gecachte, solange es noch mindestens
  /// eine Minute läuft, sonst still über das Refresh-Token erneuert.
  ///
  /// Wirft [GoogleAuthException], wenn kein Konto verbunden ist oder Google
  /// das Refresh-Token abgelehnt hat (dann hilft nur neu anmelden — z.B. wenn
  /// der Consent-Screen noch auf „Testing" steht und die 7 Tage um sind).
  ///
  /// Hier **kein** `prompt` und kein `access_type`: der Refresh läuft ohne
  /// Browser und ohne Nutzerinteraktion.
  Future<String> accessToken() async {
    final cached = _accessToken;
    final expiry = _accessTokenExpiry;
    if (cached != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return cached;
    }

    final refresh = await _storage.read(key: _refreshTokenKey);
    if (refresh == null) {
      throw const GoogleAuthException('Kein Google-Konto verbunden.');
    }

    final result = await _appAuth.token(
      TokenRequest(
        GoogleConfig.clientId,
        GoogleConfig.redirectUrl,
        serviceConfiguration: _serviceConfig,
        refreshToken: refresh,
        scopes: _scopes,
      ),
    );
    await _store(result);

    final token = _accessToken;
    if (token == null) {
      throw const GoogleAuthException('Token-Erneuerung fehlgeschlagen.');
    }
    return token;
  }

  /// Übernimmt eine Token-Antwort. Google schickt beim Refresh **kein** neues
  /// Refresh-Token mit — deshalb wird das alte nur überschrieben, wenn
  /// tatsächlich eins dabei ist, und nie gelöscht.
  Future<void> _store(
    TokenResponse? result, {
    bool requireRefreshToken = false,
  }) async {
    if (result == null) {
      throw const GoogleAuthException('Anmeldung abgebrochen.');
    }
    _accessToken = result.accessToken;
    _accessTokenExpiry = result.accessTokenExpirationDateTime;

    final refresh = result.refreshToken;
    if (refresh != null) {
      await _storage.write(key: _refreshTokenKey, value: refresh);
    } else if (requireRefreshToken) {
      throw const GoogleAuthException(
        'Google hat kein Refresh-Token geliefert. Zugriff unter '
        'myaccount.google.com → Sicherheit → Drittanbieter-Apps entfernen '
        'und erneut anmelden.',
      );
    }
  }
}