import 'package:dio/dio.dart';

import 'secure_storage.dart';

/// http://localhost fonctionne sur le simulateur iOS (il partage le réseau du
/// Mac hôte), mais pas sur un iPhone physique où `localhost` désigne le
/// téléphone lui-même. Pour tester sur device réel, dev.myrunner.fr est un
/// enregistrement DNS A pointant vers l'IP LAN du Mac (chez IONOS) — si le
/// routeur réattribue une autre IP, seul cet enregistrement DNS doit être mis
/// à jour, pas ce fichier. L'exception ATS correspondante est dans
/// ios/Runner/Info.plist et doit matcher ce même nom de domaine.
const apiBaseUrl = 'http://dev.myrunner.fr:8000';

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
