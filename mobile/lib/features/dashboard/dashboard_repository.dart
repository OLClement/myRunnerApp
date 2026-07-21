import '../../core/api_client.dart';
import 'dashboard_data.dart';

class DashboardRepository {
  Future<DashboardData> load({String period = '1y'}) async {
    final response = await ApiClient.instance.dio.get('/dashboard', queryParameters: {'period': period});
    return DashboardData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DailyDashboardData> loadDaily({String period = '1y'}) async {
    final response = await ApiClient.instance.dio.get('/dashboard/daily', queryParameters: {'period': period});
    return DailyDashboardData.fromJson(response.data as Map<String, dynamic>);
  }
}
