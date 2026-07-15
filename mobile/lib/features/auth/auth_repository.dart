import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../core/api_client.dart';
import '../../core/secure_storage.dart';

class AuthException implements Exception {
  AuthException(this.code);
  final String code;

  @override
  String toString() => 'AuthException($code)';
}

class AuthRepository {
  Future<void> loginWithStrava() async {
    final result = await FlutterWebAuth2.authenticate(
      url: '$apiBaseUrl/auth/strava/login',
      callbackUrlScheme: 'myrunner',
    );

    final uri = Uri.parse(result);
    final error = uri.queryParameters['error'];
    if (error != null) {
      throw AuthException(error);
    }

    final accessToken = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];
    if (accessToken == null || refreshToken == null) {
      throw AuthException('missing_tokens');
    }

    await SecureStorage.instance.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
  }
}
