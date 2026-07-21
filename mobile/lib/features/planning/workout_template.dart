class WorkoutTemplate {
  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.sportType,
    required this.durationMin,
    required this.zone,
    required this.description,
  });

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id'] as int,
      name: json['name'] as String,
      sportType: json['sport_type'] as String?,
      durationMin: json['duration_min'] as int?,
      zone: json['zone'] as String?,
      description: json['description'] as String?,
    );
  }

  final int id;
  final String name;
  final String? sportType;
  final int? durationMin;
  final String? zone;
  final String? description;
}
