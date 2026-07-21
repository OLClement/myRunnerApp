import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import 'activities_repository.dart';
import 'activity.dart';
import 'sport_style.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final _repository = ActivitiesRepository();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  List<Activity> _activities = [];
  bool _loading = true;
  bool _fullSyncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final activities = await _repository.list();
      setState(() {
        _activities = activities;
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

  Future<void> _syncAndReload() async {
    try {
      await _repository.sync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync échouée ($e)')));
      }
    }
    await _load();
  }

  Future<void> _confirmAndFullSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resynchroniser tout l\'historique ?'),
        content: const Text(
          'Supprime les activités enregistrées localement et les retélécharge depuis Strava '
          '(jusqu\'à 2 ans en arrière). Peut prendre plusieurs minutes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resynchroniser')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _fullSyncing = true);
    try {
      await _repository.syncFull();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resync échouée ($e)')));
      }
    }
    if (mounted) setState(() => _fullSyncing = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activités'),
        actions: [
          IconButton(
            onPressed: _fullSyncing ? null : _syncAndReload,
            icon: const Icon(Icons.sync),
            tooltip: 'Sync récente',
          ),
          IconButton(
            onPressed: _fullSyncing ? null : _confirmAndFullSync,
            icon: const Icon(Icons.history),
            tooltip: 'Resync complet',
          ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _syncAndReload,
                      child: _activities.isEmpty
                          ? ListView(
                              children: const [
                                Padding(
                                  padding: EdgeInsets.only(top: 120),
                                  child: Center(child: Text('Aucune activité — tire vers le bas pour synchroniser')),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _activities.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _ActivityCard(activity: _activities[index], dateFormat: _dateFormat);
                              },
                            ),
                    ),
          if (_fullSyncing)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Resynchronisation en cours…'),
                      ],
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.dateFormat});

  final Activity activity;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sport = SportStyle.of(activity.sportType);
    final sportColor = sport.color(isDark);
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    final details = [
      if (activity.startDate != null) dateFormat.format(activity.startDate!),
      if (activity.distanceKm != null) '${activity.distanceKm!.toStringAsFixed(1)} km',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow(isDark),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: sportColor.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(sport.icon, color: sportColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sport.label}${details.isNotEmpty ? ' · $details' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: inkSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                activity.chargeLoad != null ? activity.chargeLoad!.toStringAsFixed(0) : '-',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.accentDark : AppColors.accentLight,
                ),
              ),
              Text('charge', style: TextStyle(fontSize: 10, color: inkSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
