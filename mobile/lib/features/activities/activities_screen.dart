import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'activities_repository.dart';
import 'activity.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activités')),
      body: _loading
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
                      : ListView.builder(
                          itemCount: _activities.length,
                          itemBuilder: (context, index) {
                            final a = _activities[index];
                            return ListTile(
                              title: Text(a.name),
                              subtitle: Text(
                                '${a.sportType} · ${a.startDate != null ? _dateFormat.format(a.startDate!) : '-'}'
                                '${a.distanceKm != null ? ' · ${a.distanceKm!.toStringAsFixed(1)} km' : ''}',
                              ),
                              trailing: Text(a.chargeLoad != null ? a.chargeLoad!.toStringAsFixed(0) : '-'),
                            );
                          },
                        ),
                ),
    );
  }
}
