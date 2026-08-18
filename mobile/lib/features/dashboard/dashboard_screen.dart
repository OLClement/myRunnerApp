import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/kenko_widgets.dart';
import '../../core/theme.dart';
import 'dashboard_data.dart';
import 'dashboard_repository.dart';

const _periodOptions = [
  ('3m', '3M'),
  ('6m', '6M'),
  ('1y', '1A'),
  ('2y', '2A'),
  ('all', 'Tout'),
];

const _metricOptions = [
  ('charge', 'Charge'),
  ('distance', 'Distance'),
  ('duration', 'Durée'),
];

const _zoneOrder = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = DashboardRepository();
  DashboardData? _data;
  DailyDashboardData? _daily;
  bool _loading = true;
  String? _error;

  String _period = '1y';
  String _metric = 'charge';
  String _sport = 'Tout';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repository.load(period: _period),
        _repository.loadDaily(period: _period),
      ]);
      setState(() {
        _data = results[0] as DashboardData;
        _daily = results[1] as DailyDashboardData;
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

  void _onPeriodChanged(String period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Réglages',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : RefreshIndicator(
                onRefresh: _load,
                child: _buildContent(context, _data!, _daily!),
              ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardData data,
    DailyDashboardData daily,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark
        ? AppColors.inkSecondaryDark
        : AppColors.inkSecondaryLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        _StatGrid(data: data),
        const SizedBox(height: 12),
        Divider(height: 1, color: inkSecondary.withValues(alpha: 0.15)),
        const SizedBox(height: 16),
        _PeriodSelector(period: _period, onChanged: _onPeriodChanged),
        const SizedBox(height: 16),
        _ChargeHeroCard(
          data: data,
          metric: _metric,
          sport: _sport,
          onMetricChanged: (m) => setState(() => _metric = m),
          onSportChanged: (s) => setState(() => _sport = s),
        ),
        const SizedBox(height: 16),
        _DailyBandCard(data: daily),
        const SizedBox(height: 16),
        _ZoneDistributionCard(data: data),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final ratioSign = data.ratio >= 0 ? '+' : '';
    return StatRow(
      items: [
        StatItem(
          value: data.chargeCurrent.toStringAsFixed(0),
          label: 'Cette semaine',
        ),
        StatItem(
          value: data.chargeLast.toStringAsFixed(0),
          label: 'Semaine dernière',
        ),
        StatItem(
          value: data.avg4w.toStringAsFixed(0),
          label: 'Moy. 4 semaines',
        ),
        StatItem(
          value: '$ratioSign${data.ratio.toStringAsFixed(0)}%',
          label:
              'vs moy. 4S · proj. ${data.chargeProjected.toStringAsFixed(0)}',
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});

  final String period;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondaryDark
        : AppColors.inkSecondaryLight;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in _periodOptions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(option.$2),
                selected: period == option.$1,
                onSelected: (_) => onChanged(option.$1),
                selectedColor: accent,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: period == option.$1 ? Colors.white : inkSecondary,
                ),
                backgroundColor: isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm * 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bloc "hero" bleu marine mettant en avant le graphe de charge — couleur
/// fixe (ne suit pas le thème clair/sombre), toujours rendu avec la variante
/// sombre de la palette catégorielle puisqu'elle est déjà calibrée pour un
/// fond très sombre.
class _ChargeHeroCard extends StatelessWidget {
  const _ChargeHeroCard({
    required this.data,
    required this.metric,
    required this.sport,
    required this.onMetricChanged,
    required this.onSportChanged,
  });

  final DashboardData data;
  final String metric;
  final String sport;
  final ValueChanged<String> onMetricChanged;
  final ValueChanged<String> onSportChanged;

  @override
  Widget build(BuildContext context) {
    final metricLabel = _metricOptions.firstWhere((m) => m.$1 == metric).$2;

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Charge hebdomadaire',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              _SportDropdown(
                sportTypes: data.sportTypes,
                selected: sport,
                onChanged: onSportChanged,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetricToggle(metric: metric, onChanged: onMetricChanged),
          const SizedBox(height: 10),
          _ChartLegend(metricLabel: metricLabel),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _WeeklyLoadChart(
              labels: data.labels,
              values: data.metricSeries(metric, sport),
              movingAvg: data.movingAvg[metric] ?? const [],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricToggle extends StatelessWidget {
  const _MetricToggle({required this.metric, required this.onChanged});

  final String metric;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          for (final option in _metricOptions)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: metric == option.$1
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm - 2),
                  ),
                  child: Text(
                    option.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: metric == option.$1
                          ? Colors.white
                          : AppColors.navyMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SportDropdown extends StatelessWidget {
  const _SportDropdown({
    required this.sportTypes,
    required this.selected,
    required this.onChanged,
  });

  final List<String> sportTypes;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: selected,
      onSelected: onChanged,
      color: AppColors.surfaceDark,
      itemBuilder: (context) => [
        for (final sport in sportTypes)
          PopupMenuItem(
            value: sport,
            child: Text(sport, style: const TextStyle(color: Colors.white)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.metricLabel});

  final String metricLabel;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.categoricalDark;

    Widget dot(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.navyMuted),
          ),
        ],
      );
    }

    return Row(
      children: [
        dot(palette[0], '$metricLabel hebdo'),
        const SizedBox(width: 16),
        dot(palette[3], 'Moyenne mobile 4 sem.'),
      ],
    );
  }
}

/// Combine un [BarChart] (barres, série sélectionnée) et un [LineChart]
/// transparent superposé (moyenne mobile) — fl_chart n'a pas de widget combo
/// natif. Les deux charts partagent les mêmes tailles d'axes (`reservedSize`)
/// pour que leurs zones de tracé s'alignent pixel pour pixel.
class _WeeklyLoadChart extends StatelessWidget {
  const _WeeklyLoadChart({
    required this.labels,
    required this.values,
    required this.movingAvg,
  });

  final List<String> labels;
  final List<double> values;
  final List<double> movingAvg;

  static const _leftReserved = 32.0;
  static const _bottomReserved = 24.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.categoricalDark;
    const gridColor = Color(0xFF2A2D4A);
    const mutedInk = AppColors.navyMuted;

    if (values.isEmpty) {
      return const Center(
        child: Text(
          'Pas encore de données — synchronise tes activités.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final n = values.length;
    final maxY =
        [...values, ...movingAvg].reduce((a, b) => a > b ? a : b) * 1.15;
    final effectiveMaxY = maxY == 0 ? 10.0 : maxY;
    // BarChart ignores SideTitles.interval (unlike LineChart) — it builds one title
    // per bar regardless, so skipping has to happen manually inside getTitlesWidget.
    final bottomStep = (labels.length / 4).ceil().clamp(1, 999);

    Widget bottomLabel(double value, TitleMeta meta) {
      final i = value.toInt();
      if (i < 0 || i >= labels.length || i % bottomStep != 0)
        return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          labels[i],
          style: const TextStyle(fontSize: 9, color: mutedInk),
        ),
      );
    }

    return Stack(
      children: [
        BarChart(
          BarChartData(
            minY: 0,
            maxY: effectiveMaxY,
            alignment: BarChartAlignment.spaceBetween,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: effectiveMaxY / 4,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: gridColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      rod.toY.toStringAsFixed(0),
                      const TextStyle(color: Colors.white),
                    ),
              ),
            ),
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
                  reservedSize: _leftReserved,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: mutedInk),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: _bottomReserved,
                  getTitlesWidget: bottomLabel,
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < n; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      color: palette[0],
                      width: 8,
                      borderRadius: BorderRadius.zero,
                    ),
                  ],
                ),
            ],
          ),
        ),
        LineChart(
          LineChartData(
            minX: 0,
            maxX: (n - 1).toDouble(),
            minY: 0,
            maxY: effectiveMaxY,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              // showTitles doit rester `true` ici (fl_chart ignore reservedSize sinon) —
              // seul le widget rendu est vide, pour que les deux charts gardent la même
              // largeur de zone de tracé.
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: _leftReserved,
                  getTitlesWidget: (_, _) => const SizedBox.shrink(),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: _bottomReserved,
                  getTitlesWidget: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < movingAvg.length; i++)
                    FlSpot(i.toDouble(), movingAvg[i]),
                ],
                isCurved: true,
                color: palette[3],
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyBandCard extends StatelessWidget {
  const _DailyBandCard({required this.data});

  final DailyDashboardData data;

  @override
  Widget build(BuildContext context) {
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
            'Charge journalière — MM7j',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'avec canal ± 1 écart-type (28j)',
            style: TextStyle(fontSize: 11, color: AppColors.navyMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: _DailyBandChart(data: data)),
        ],
      ),
    );
  }
}

class _DailyBandChart extends StatelessWidget {
  const _DailyBandChart({required this.data});

  final DailyDashboardData data;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.categoricalDark;
    const gridColor = Color(0xFF2A2D4A);
    const mutedInk = AppColors.navyMuted;

    if (data.mm7.isEmpty) {
      return const Center(
        child: Text(
          'Pas encore de données — synchronise tes activités.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final n = data.mm7.length;
    final maxY = data.bandHigh.reduce((a, b) => a > b ? a : b) * 1.15;
    final effectiveMaxY = maxY == 0 ? 10.0 : maxY;
    final bottomInterval = (data.labels.length / 4)
        .clamp(1, double.infinity)
        .roundToDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: effectiveMaxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: effectiveMaxY / 4,
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
              interval: bottomInterval,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.labels.length)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _shortDate(data.labels[i]),
                    style: const TextStyle(fontSize: 9, color: mutedInk),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    s.y.toStringAsFixed(0),
                    const TextStyle(color: Colors.white),
                  ),
                )
                .toList(),
          ),
        ),
        betweenBarsData: [
          BetweenBarsData(
            fromIndex: 0,
            toIndex: 1,
            color: palette[4].withValues(alpha: 0.18),
          ),
        ],
        lineBarsData: [
          // bande basse/haute : lignes invisibles, uniquement utilisées comme bornes
          // du remplissage via betweenBarsData ci-dessus.
          LineChartBarData(
            spots: [
              for (var i = 0; i < data.bandLow.length; i++)
                FlSpot(i.toDouble(), data.bandLow[i]),
            ],
            isCurved: true,
            color: Colors.transparent,
            barWidth: 0,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: [
              for (var i = 0; i < data.bandHigh.length; i++)
                FlSpot(i.toDouble(), data.bandHigh[i]),
            ],
            isCurved: true,
            color: Colors.transparent,
            barWidth: 0,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: [
              for (var i = 0; i < data.mm7.length; i++)
                FlSpot(i.toDouble(), data.mm7[i]),
            ],
            isCurved: true,
            color: palette[0],
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

String _shortDate(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}/${parts[1]}';
}

class _ZoneDistributionCard extends StatelessWidget {
  const _ZoneDistributionCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 10),
          const _ZoneLegend(),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: _ZoneChart(data: data)),
        ],
      ),
    );
  }
}

class _ZoneLegend extends StatelessWidget {
  const _ZoneLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final zone in _zoneOrder)
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
              const SizedBox(width: 3),
              Text(
                zone,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.navyMuted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ZoneChart extends StatelessWidget {
  const _ZoneChart({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    const mutedInk = AppColors.navyMuted;
    const gridColor = Color(0xFF2A2D4A);

    final labels = data.labels;
    if (labels.isEmpty) {
      return const Center(
        child: Text(
          'Pas encore de données — synchronise tes activités.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // BarChart ignores SideTitles.interval (unlike LineChart) — skip labels manually.
    final bottomStep = (labels.length / 4).ceil().clamp(1, 999);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceBetween,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
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
              reservedSize: 36,
              interval: 25,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}%',
                style: TextStyle(fontSize: 10, color: mutedInk),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length || i % bottomStep != 0)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    labels[i],
                    style: TextStyle(fontSize: 9, color: mutedInk),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < labels.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _zoneOrder.fold(
                    0.0,
                    (sum, z) => sum + (data.zoneData[z]?[i] ?? 0),
                  ),
                  color: Colors.transparent,
                  width: 8,
                  borderRadius: BorderRadius.zero,
                  rodStackItems: _stackItems(i),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<BarChartRodStackItem> _stackItems(int i) {
    var cumulative = 0.0;
    final items = <BarChartRodStackItem>[];
    for (final zone in _zoneOrder) {
      final value = data.zoneData[zone]?[i] ?? 0;
      items.add(
        BarChartRodStackItem(
          cumulative,
          cumulative + value,
          AppColors.zoneColor(zone),
        ),
      );
      cumulative += value;
    }
    return items;
  }
}
