import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'dashboard_data.dart';
import 'dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = DashboardRepository();
  DashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repository.load();
      setState(() {
        _data = data;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/activities'),
        label: const Text('Activités'),
        icon: const Icon(Icons.list),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _buildContent(context, _data!),
                  ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DashboardData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Cette semaine', value: data.chargeCurrent)),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(label: 'Moy. 4 sem.', value: data.avg4w)),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(label: 'Projection', value: data.chargeProjected)),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Charge hebdomadaire', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 4),
        const _ChartLegend(),
        const SizedBox(height: 12),
        SizedBox(height: 240, child: _WeeklyLoadChart(data: data)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toStringAsFixed(0),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppColors.categoricalDark : AppColors.categoricalLight;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    Widget dot(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: inkSecondary)),
        ],
      );
    }

    return Row(
      children: [
        dot(palette[0], 'Charge hebdo'),
        const SizedBox(width: 16),
        dot(palette[7], 'Moyenne mobile 4 sem.'),
      ],
    );
  }
}

class _WeeklyLoadChart extends StatelessWidget {
  const _WeeklyLoadChart({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppColors.categoricalDark : AppColors.categoricalLight;
    final gridColor = isDark ? const Color(0xFF2C2C2A) : const Color(0xFFE1E0D9);
    final mutedInk = AppColors.inkMuted;

    if (data.weeklyTotal.isEmpty) {
      return const Center(child: Text('Pas encore de données — synchronise tes activités.'));
    }

    final maxY = [...data.weeklyTotal, ...data.movingAvg].reduce((a, b) => a > b ? a : b) * 1.15;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY == 0 ? 10 : maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) =>
                  Text(value.toInt().toString(), style: TextStyle(fontSize: 10, color: mutedInk)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (data.labels.length / 4).clamp(1, double.infinity).roundToDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(data.labels[i], style: TextStyle(fontSize: 9, color: mutedInk)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(s.y.toStringAsFixed(0), const TextStyle(color: Colors.white)))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < data.weeklyTotal.length; i++) FlSpot(i.toDouble(), data.weeklyTotal[i])],
            isCurved: false,
            color: palette[0],
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: palette[0].withValues(alpha: 0.08)),
          ),
          LineChartBarData(
            spots: [for (var i = 0; i < data.movingAvg.length; i++) FlSpot(i.toDouble(), data.movingAvg[i])],
            isCurved: true,
            color: palette[7],
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
