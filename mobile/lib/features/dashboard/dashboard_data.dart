class DashboardData {
  DashboardData({
    required this.labels,
    required this.weeklyTotal,
    required this.movingAvg,
    required this.chargeCurrent,
    required this.chargeLast,
    required this.avg4w,
    required this.chargeProjected,
    required this.ratio,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final weeklyData = json['weekly_data'] as Map<String, dynamic>;
    final tout = (weeklyData['Tout'] as List).map((e) => (e as num).toDouble()).toList();

    return DashboardData(
      labels: (json['labels'] as List).cast<String>(),
      weeklyTotal: tout,
      movingAvg: (json['moving_avg'] as List).map((e) => (e as num).toDouble()).toList(),
      chargeCurrent: (json['charge_current'] as num).toDouble(),
      chargeLast: (json['charge_last'] as num).toDouble(),
      avg4w: (json['avg_4w'] as num).toDouble(),
      chargeProjected: (json['charge_projected'] as num).toDouble(),
      ratio: (json['ratio'] as num).toDouble(),
    );
  }

  final List<String> labels;
  final List<double> weeklyTotal;
  final List<double> movingAvg;
  final double chargeCurrent;
  final double chargeLast;
  final double avg4w;
  final double chargeProjected;
  final double ratio;
}
