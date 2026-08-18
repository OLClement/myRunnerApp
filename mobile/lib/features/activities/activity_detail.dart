import 'dart:convert';

class ActivityDetail {
  ActivityDetail({
    required this.id,
    required this.name,
    required this.sportType,
    required this.startDate,
    required this.distanceKm,
    required this.durationMin,
    required this.avgHr,
    required this.totalElevation,
    required this.chargeLoad,
    required this.zoneMinutes,
    required this.hrData,
    required this.velocityData,
  });

  factory ActivityDetail.fromJson(Map<String, dynamic> json) {
    return ActivityDetail(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      sportType: json['sport_type'] as String? ?? '',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      durationMin: (json['duration_min'] as num?)?.toDouble(),
      avgHr: (json['avg_hr'] as num?)?.toDouble(),
      totalElevation: (json['total_elevation'] as num?)?.toDouble(),
      chargeLoad: (json['charge_load'] as num?)?.toDouble(),
      zoneMinutes: {
        // "sous Z1" (échauffement/récup) fondu dans Z1, même convention que le dashboard.
        'Z1':
            ((json['z1_min'] as num?)?.toDouble() ?? 0) +
            ((json['below_z1_min'] as num?)?.toDouble() ?? 0),
        'Z2': (json['z2_min'] as num?)?.toDouble() ?? 0,
        'Z3': (json['z3_min'] as num?)?.toDouble() ?? 0,
        'Z4': (json['z4_min'] as num?)?.toDouble() ?? 0,
        'Z5': (json['z5_min'] as num?)?.toDouble() ?? 0,
      },
      hrData: _parseSamples(json['hr_data'] as String?),
      velocityData: _parseSamples(json['velocity_data'] as String?),
    );
  }

  static List<double> _parseSamples(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
  }

  final int id;
  final String name;
  final String sportType;
  final DateTime? startDate;
  final double? distanceKm;
  final double? durationMin;
  final double? avgHr;
  final double? totalElevation;
  final double? chargeLoad;

  /// Minutes par zone (Z1-Z5) — le temps "sous Z1" (échauffement/récup) est
  /// fondu dans Z1, même convention que le graphique du dashboard.
  final Map<String, double> zoneMinutes;

  /// Un échantillon ≈ 1 seconde d'activité, cf. strava_service.py.
  final List<double> hrData;
  final List<double> velocityData;
}
