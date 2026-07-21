import '../../core/api_client.dart';
import 'settings.dart';

class SettingsRepository {
  Future<Settings> get() async {
    final response = await ApiClient.instance.dio.get('/me');
    return Settings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Settings> update(Settings settings) async {
    final response = await ApiClient.instance.dio.put('/me', data: settings.toJson());
    return Settings.fromJson(response.data as Map<String, dynamic>);
  }
}
