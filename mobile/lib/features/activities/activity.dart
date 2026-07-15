class Activity {
  Activity({
    required this.id,
    required this.name,
    required this.sportType,
    required this.startDate,
    required this.distanceKm,
    required this.durationMin,
    required this.chargeLoad,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      sportType: json['sport_type'] as String? ?? '',
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      durationMin: (json['duration_min'] as num?)?.toDouble(),
      chargeLoad: (json['charge_load'] as num?)?.toDouble(),
    );
  }

  final int id;
  final String name;
  final String sportType;
  final DateTime? startDate;
  final double? distanceKm;
  final double? durationMin;
  final double? chargeLoad;
}
