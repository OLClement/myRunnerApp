List<double> _toDoubleList(dynamic list) => (list as List).map((e) => (e as num).toDouble()).toList();

Map<String, List<double>> _toDoubleListMap(dynamic map) =>
    (map as Map<String, dynamic>).map((key, value) => MapEntry(key, _toDoubleList(value)));

class DashboardData {
  DashboardData({
    required this.labels,
    required this.series,
    required this.movingAvg,
    required this.zoneData,
    required this.sportTypes,
    required this.chargeCurrent,
    required this.chargeLast,
    required this.avg4w,
    required this.chargeProjected,
    required this.ratio,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final seriesJson = json['series'] as Map<String, dynamic>;
    return DashboardData(
      labels: (json['labels'] as List).cast<String>(),
      series: seriesJson.map((metric, groups) => MapEntry(metric, _toDoubleListMap(groups))),
      movingAvg: _toDoubleListMap(json['moving_avg']),
      zoneData: _toDoubleListMap(json['zone_data']),
      sportTypes: (json['sport_types'] as List).cast<String>(),
      chargeCurrent: (json['charge_current'] as num).toDouble(),
      chargeLast: (json['charge_last'] as num).toDouble(),
      avg4w: (json['avg_4w'] as num).toDouble(),
      chargeProjected: (json['charge_projected'] as num).toDouble(),
      ratio: (json['ratio'] as num).toDouble(),
    );
  }

  final List<String> labels;
  final Map<String, Map<String, List<double>>> series; // metric -> sport group -> weekly values
  final Map<String, List<double>> movingAvg; // metric -> weekly values
  final Map<String, List<double>> zoneData; // Z1..Z5 -> weekly % of classified HR time
  final List<String> sportTypes;
  final double chargeCurrent;
  final double chargeLast;
  final double avg4w;
  final double chargeProjected;
  final double ratio;

  List<double> metricSeries(String metric, String sport) => series[metric]?[sport] ?? const [];
}

class DailyDashboardData {
  DailyDashboardData({
    required this.labels,
    required this.dailyCharge,
    required this.mm7,
    required this.bandLow,
    required this.bandHigh,
  });

  factory DailyDashboardData.fromJson(Map<String, dynamic> json) {
    return DailyDashboardData(
      labels: (json['labels'] as List).cast<String>(),
      dailyCharge: _toDoubleList(json['daily_charge']),
      mm7: _toDoubleList(json['mm7']),
      bandLow: _toDoubleList(json['band_low']),
      bandHigh: _toDoubleList(json['band_high']),
    );
  }

  final List<String> labels;
  final List<double> dailyCharge;
  final List<double> mm7;
  final List<double> bandLow;
  final List<double> bandHigh;
}
