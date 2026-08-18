import '../../core/api_client.dart';
import 'activity.dart';
import 'activity_detail.dart';

class ActivitiesRepository {
  Future<List<Activity>> list() async {
    final response = await ApiClient.instance.dio.get('/activities');
    return (response.data as List).map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ActivityDetail> getById(int id) async {
    final response = await ApiClient.instance.dio.get('/activities/$id');
    return ActivityDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> sync() async {
    await ApiClient.instance.dio.post('/activities/sync');
  }

  Future<void> syncFull() async {
    await ApiClient.instance.dio.post('/activities/sync/full');
  }
}
