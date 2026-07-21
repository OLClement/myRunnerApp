class PlannedWorkout {
  PlannedWorkout({
    required this.id,
    required this.templateId,
    required this.plannedDate,
    required this.status,
    required this.matchedActivityId,
    required this.templateName,
    required this.sportType,
    required this.durationMin,
    required this.zone,
  });

  factory PlannedWorkout.fromJson(Map<String, dynamic> json) {
    return PlannedWorkout(
      id: json['id'] as int,
      templateId: json['template_id'] as int,
      plannedDate: json['planned_date'] != null ? DateTime.parse(json['planned_date'] as String) : null,
      status: json['status'] as String,
      matchedActivityId: json['matched_activity_id'] as int?,
      templateName: json['template_name'] as String,
      sportType: json['sport_type'] as String?,
      durationMin: json['duration_min'] as int?,
      zone: json['zone'] as String?,
    );
  }

  final int id;
  final int templateId;
  final DateTime? plannedDate;
  final String status;
  final int? matchedActivityId;
  final String templateName;
  final String? sportType;
  final int? durationMin;
  final String? zone;
}
