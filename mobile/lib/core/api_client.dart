import 'package:dio/dio.dart';

import 'secure_storage.dart';

/// Le backend est déployé sur Render sous le domaine custom `api.myrunner.fr`
/// (HTTPS, accessible de partout — plus de dépendance au Mac/Wi-Fi maison).
/// Le compte Strava (client_id partagé avec l'ancienne webapp Flask sur
/// myrunner.fr) a son "Authorization Callback Domain" réglé sur `myrunner.fr`
/// (domaine racine) — Strava couvre alors tous les sous-domaines
/// automatiquement, donc le login fonctionne aussi bien ici que sur le
/// backend local (`dev.myrunner.fr`) sans jamais avoir à retoucher ce réglage.
/// Pour développer contre le backend local, relancer avec
/// `flutter run --dart-define=API_BASE_URL=http://localhost:8000` (simulateur)
/// ou `--dart-define=API_BASE_URL=http://dev.myrunner.fr:8000` (device
/// physique, cf. CLAUDE.md).
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.myrunner.fr',
);

class ApiClient {
  ApiClient._() {
    _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.instance.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final clone = await _dio.fetch(error.requestOptions);
              return handler.resolve(clone);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static final instance = ApiClient._();

  late final Dio _dio;

  Dio get dio => _dio;

  /// Tente de restaurer une session existante (refresh token en Keychain) au
  /// démarrage de l'app, pour éviter de repasser par l'écran de login à
  /// chaque lancement. Retourne `false` si aucun refresh token n'est stocké
  /// ou s'il n'est plus valide (auquel cas le Keychain a été nettoyé).
  Future<bool> restoreSession() async {
    try {
      final refreshToken = await SecureStorage.instance.readRefreshToken().timeout(const Duration(seconds: 5));
      if (refreshToken == null) return false;
      return await _tryRefresh();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await SecureStorage.instance.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await Dio(BaseOptions(baseUrl: apiBaseUrl)).post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newAccessToken = response.data['access_token'] as String;
      await SecureStorage.instance.saveTokens(
        accessToken: newAccessToken,
        refreshToken: refreshToken,
      );
      return true;
    } catch (_) {
      await SecureStorage.instance.clear();
      return false;
    }
  }
}
