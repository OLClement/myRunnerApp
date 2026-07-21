import '../../core/api_client.dart';
import 'activity.dart';

class ActivitiesRepository {
  Future<List<Activity>> list() async {
    final response = await ApiClient.instance.dio.get('/activities');
    return (response.data as List).map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> sync() async {
    await ApiClient.instance.dio.post('/activities/sync');
  }

  Future<void> syncFull() async {
    await ApiClient.instance.dio.post('/activities/sync/full');
  }
}
