import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/kenko_widgets.dart';
import '../../core/theme.dart';
import 'activities_repository.dart';
import 'activity_detail.dart';
import 'charge_style.dart';
import 'sport_style.dart';

const _zoneOrder = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];

class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final int activityId;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final _repository = ActivitiesRepository();
  final _dateFormat = DateFormat('EEEE d MMMM yyyy · HH:mm', 'fr_FR');

  ActivityDetail? _activity;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final activity = await _repository.getById(widget.activityId);
      setState(() {
        _activity = activity;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement ($e)';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark
        ? AppColors.inkSecondaryDark
        : AppColors.inkSecondaryLight;

    return Scaffold(
      // Pas de titre dans l'AppBar (juste la flèche retour, déjà fournie par
      // `automaticallyImplyLeading`) — les noms d'activité peuvent être longs
      // et l'AppBar les tronquait ("Simulateur d'escali…"). Le nom complet vit
      // dans le corps de page, en grand et libre de passer à la ligne, comme
      // les titres des autres écrans (Dashboard, Activités, Planning).
      appBar: AppBar(title: activity == null ? const Text('Activité') : null),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                Text(
                  activity!.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 27,
                  ),
                ),
                const SizedBox(height: 16),
                _HeaderCard(activity: activity, dateFormat: _dateFormat),
                const SizedBox(height: 16),
                _StatsGrid(activity: activity),
                const SizedBox(height: 12),
                Divider(height: 1, color: inkSecondary.withValues(alpha: 0.15)),
                const SizedBox(height: 16),
                if (activity.zoneMinutes.values.any((v) => v > 0)) ...[
                  _ZoneBreakdownCard(activity: activity),
                  const SizedBox(height: 16),
                ],
                if (activity.hrData.isNotEmpty)
                  _HrCurveCard(activity: activity),
              ],
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.activity, required this.dateFormat});

  final ActivityDetail activity;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sport = SportStyle.of(activity.sportType);
    final sportColor = sport.color(isDark);
    final inkSecondary = isDark
        ? AppColors.inkSecondaryDark
        : AppColors.inkSecondaryLight;

    // Pas de card : sur la référence Kenko, l'en-tête (icône + sport + date)
    // repose directement sur le fond de page, comme les rangées de stats.
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: sportColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(sport.icon, color: sportColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sport.label,
                style: TextStyle(fontSize: 12, color: inkSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                activity.startDate != null
                    ? dateFormat.format(activity.startDate!)
                    : '',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.activity});

  final ActivityDetail activity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StatRow(
      items: [
        StatItem(
          label: 'Distance',
          value: activity.distanceKm != null
              ? activity.distanceKm!.toStringAsFixed(1)
              : '-',
          unit: activity.distanceKm != null ? 'km' : null,
        ),
        StatItem(
          label: 'Durée',
          value: activity.durationMin != null
              ? activity.durationMin!.round().toString()
              : '-',
          unit: activity.durationMin != null ? 'min' : null,
        ),
        StatItem(
          label: 'FC moy.',
          value: activity.avgHr != null
              ? activity.avgHr!.round().toString()
              : '-',
          unit: activity.avgHr != null ? 'bpm' : null,
        ),
        StatItem(
          label: 'Charge',
          value: activity.chargeLoad != null
              ? activity.chargeLoad!.toStringAsFixed(0)
              : '-',
          valueColor: chargeColor(activity.chargeLoad, isDark),
        ),
      ],
    );
  }
}

class _ZoneBreakdownCard extends StatelessWidget {
  const _ZoneBreakdownCard({required this.activity});

  final ActivityDetail activity;

  @override
  Widget build(BuildContext context) {
    final total = activity.zoneMinutes.values.fold(0.0, (sum, v) => sum + v);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.zero,
        boxShadow: AppTheme.heroCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition zones FC',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  for (final zone in _zoneOrder)
                    if ((activity.zoneMinutes[zone] ?? 0) > 0)
                      Expanded(
                        flex: ((activity.zoneMinutes[zone]! / total) * 1000)
                            .round()
                            .clamp(1, 1000),
                        child: Container(color: AppColors.zoneColor(zone)),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final zone in _zoneOrder)
                if ((activity.zoneMinutes[zone] ?? 0) > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.zoneColor(zone),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$zone · ${activity.zoneMinutes[zone]!.round()} min',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.navyMuted,
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HrCurveCard extends StatelessWidget {
  const _HrCurveCard({required this.activity});

  final ActivityDetail activity;

  /// Downsample pour garder le rendu fluide sur des activités longues
  /// (échantillonnage ≈ 1/s côté backend, donc potentiellement des milliers
  /// de points).
  static const _maxPoints = 300;

  @override
  Widget build(BuildContext context) {
    final samples = activity.hrData;
    final step = (samples.length / _maxPoints).ceil().clamp(1, samples.length);
    final spots = [
      for (var i = 0; i < samples.length; i += step) FlSpot(i / 60, samples[i]),
    ];
    final minHr = samples.reduce((a, b) => a < b ? a : b);
    final maxHr = samples.reduce((a, b) => a > b ? a : b);

    const mutedInk = AppColors.navyMuted;
    const gridColor = Color(0xFF2A2D4A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.zero,
        boxShadow: AppTheme.heroCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fréquence cardiaque',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: (minHr - 10).clamp(0, double.infinity),
                maxY: maxHr + 10,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: gridColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: mutedInk),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${value.toInt()}m',
                          style: const TextStyle(fontSize: 9, color: mutedInk),
                        ),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touched) => touched
                        .map(
                          (s) => LineTooltipItem(
                            '${s.y.round()} bpm',
                            const TextStyle(color: Colors.white),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.categoricalDark[0],
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
