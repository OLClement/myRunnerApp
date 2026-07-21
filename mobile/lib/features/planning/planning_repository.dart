import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../activities/activity.dart';
import 'planned_workout.dart';
import 'workout_template.dart';

class PlanningRepository {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<WorkoutTemplate>> listTemplates() async {
    final response = await ApiClient.instance.dio.get('/planning/templates');
    return (response.data as List).map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PlannedWorkout>> listPlanned(DateTime start, DateTime end) async {
    final response = await ApiClient.instance.dio.get(
      '/planning/planned',
      queryParameters: {'start': _dateFormat.format(start), 'end': _dateFormat.format(end)},
    );
    return (response.data as List).map((e) => PlannedWorkout.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Activity>> listActivities(DateTime start, DateTime end) async {
    final response = await ApiClient.instance.dio.get(
      '/activities',
      queryParameters: {'start': _dateFormat.format(start), 'end': _dateFormat.format(end)},
    );
    return (response.data as List).map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PlannedWorkout>> listPool() async {
    final response = await ApiClient.instance.dio.get('/planning/pool');
    return (response.data as List).map((e) => PlannedWorkout.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Crée une séance planifiée soit depuis un template existant (`templateId`), soit
  /// "from scratch" (`name` + champs libres) — l'API rejette si ni l'un ni l'autre n'est
  /// fourni. `date` peut être omise : la séance reste alors dans le pool (non placée).
  Future<PlannedWorkout> createPlanned({
    int? templateId,
    DateTime? date,
    String? name,
    String? sportType,
    int? durationMin,
    String? zone,
    bool keepAsTemplate = false,
  }) async {
    final response = await ApiClient.instance.dio.post(
      '/planning/planned',
      data: {
        'template_id': ?templateId,
        if (date != null) 'planned_date': _dateFormat.format(date),
        'name': ?name,
        'sport_type': ?sportType,
        'duration_min': ?durationMin,
        'zone': ?zone,
        'keep_as_template': keepAsTemplate,
      },
    );
    return PlannedWorkout.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PlannedWorkout> updatePlannedDate(int id, DateTime date) async {
    final response = await ApiClient.instance.dio.patch(
      '/planning/planned/$id',
      data: {'planned_date': _dateFormat.format(date)},
    );
    return PlannedWorkout.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removePlanned(int id) async {
    await ApiClient.instance.dio.delete('/planning/planned/$id');
  }

  /// Lie manuellement une séance planifiée à l'activité qui l'a réalisée — utilisé quand
  /// plusieurs activités du même jour/sport rendent le matching automatique ambigu.
  Future<PlannedWorkout> matchActivity(int plannedId, int activityId) async {
    final response = await ApiClient.instance.dio.post(
      '/planning/planned/$plannedId/match',
      data: {'activity_id': activityId},
    );
    return PlannedWorkout.fromJson(response.data as Map<String, dynamic>);
  }
}
