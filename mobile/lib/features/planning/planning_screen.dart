import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../activities/activity.dart';
import '../activities/sport_style.dart';
import 'planned_workout.dart';
import 'planning_repository.dart';
import 'workout_template.dart';

const _weeksShown = 3; // S, S+1, S+2 — fenêtre resserrée pour éviter le doublon avec Activités

// Catégories "from scratch" alignées sur les entrées canoniques de sport_style.dart (mêmes
// chaînes sport_type brutes) pour que l'icône/couleur retombent juste une fois la séance créée.
const _scratchSportOptions = [
  ('Run', 'Course', Icons.directions_run),
  ('Ride', 'Vélo', Icons.directions_bike),
  ('Swim', 'Natation', Icons.pool),
  ('WeightTraining', 'Renfo', Icons.fitness_center),
  ('AlpineSki', 'Ski', Icons.downhill_skiing),
];

const _zoneOptions = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5', 'Mixte'];

typedef _DayMerge = ({List<(PlannedWorkout, Activity)> matched, List<PlannedWorkout> unmatchedPlanned, List<Activity> unmatchedActivities});

/// Associe les séances planifiées d'un jour à l'activité qui les a réalisées
/// (`PlannedWorkout.matchedActivityId`, posé par le matching auto/manuel côté
/// backend) pour qu'une paire ne rende plus deux cartes séparées. Partagé par
/// la vue Plans et la vue Calendrier (grille + sheet de détail).
_DayMerge _mergeDay(List<PlannedWorkout> planned, List<Activity> activities) {
  final activityById = {for (final a in activities) a.id: a};
  final matched = <(PlannedWorkout, Activity)>[];
  final unmatchedPlanned = <PlannedWorkout>[];
  final claimedActivityIds = <int>{};

  for (final p in planned) {
    final activity = p.matchedActivityId != null ? activityById[p.matchedActivityId] : null;
    if (activity != null) {
      matched.add((p, activity));
      claimedActivityIds.add(activity.id);
    } else {
      unmatchedPlanned.add(p);
    }
  }

  final unmatchedActivities = activities.where((a) => !claimedActivityIds.contains(a.id)).toList();
  return (matched: matched, unmatchedPlanned: unmatchedPlanned, unmatchedActivities: unmatchedActivities);
}

/// Activités non liées du jour qui pourraient correspondre à [planned] (même
/// groupe de sport que `sport_style.dart`) — sert à décider si le matching est
/// ambigu (>1) et à peupler le picker "Lier une activité".
List<Activity> _matchCandidates(PlannedWorkout planned, List<Activity> unmatchedActivities) {
  final group = SportStyle.of(planned.sportType ?? '').label;
  return unmatchedActivities.where((a) => SportStyle.of(a.sportType).label == group).toList();
}

enum _PlanningView { plans, calendar }

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  final _repository = PlanningRepository();
  static final _monthFormat = DateFormat('MMMM yyyy', 'fr_FR');
  static final _dayLabelFormat = DateFormat('EEEE d MMM', 'fr_FR');
  static final _dayMonthFormat = DateFormat('d MMM', 'fr_FR');

  _PlanningView _view = _PlanningView.plans;

  /// Lundi de la première semaine affichée (S par défaut) — vue Plans.
  late DateTime _anchorWeekStart = _mondayOf(DateTime.now());

  /// Premier jour du mois affiché — vue Calendrier.
  late DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<WorkoutTemplate> _templates = [];
  List<PlannedWorkout> _planned = [];
  List<Activity> _activities = [];
  List<PlannedWorkout> _pool = [];
  bool _loading = true;
  String? _error;

  // Auto-scroll pendant un drag depuis le pool, quand le pointeur approche du
  // haut/bas du viewport scrollable actif (Plans ou Calendrier).
  final _plansListKey = GlobalKey();
  final _plansScrollController = ScrollController();
  final _calendarScrollKey = GlobalKey();
  final _calendarScrollController = ScrollController();
  Timer? _autoScrollTimer;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _plansScrollController.dispose();
    _calendarScrollController.dispose();
    super.dispose();
  }

  static DateTime _mondayOf(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  DateTime get _calendarGridStart => _mondayOf(DateTime(_calendarMonth.year, _calendarMonth.month, 1));

  DateTime get _calendarGridEnd {
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    return lastDay.add(Duration(days: 7 - lastDay.weekday));
  }

  DateTime get _rangeStart => _view == _PlanningView.plans ? _anchorWeekStart : _calendarGridStart;

  DateTime get _rangeEnd => _view == _PlanningView.plans
      ? _anchorWeekStart.add(const Duration(days: _weeksShown * 7 - 1))
      : _calendarGridEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repository.listTemplates(),
        _repository.listPlanned(_rangeStart, _rangeEnd),
        _repository.listActivities(_rangeStart, _rangeEnd),
        _repository.listPool(),
      ]);
      setState(() {
        _templates = results[0] as List<WorkoutTemplate>;
        _planned = results[1] as List<PlannedWorkout>;
        _activities = results[2] as List<Activity>;
        _pool = results[3] as List<PlannedWorkout>;
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

  void _switchView(_PlanningView view) {
    if (view == _view) return;
    setState(() => _view = view);
    _load();
  }

  void _shiftWeeks(int weeks) {
    setState(() => _anchorWeekStart = _anchorWeekStart.add(Duration(days: 7 * weeks)));
    _load();
  }

  void _shiftMonth(int months) {
    setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + months));
    _load();
  }

  void _jumpToToday() {
    setState(() {
      if (_view == _PlanningView.plans) {
        _anchorWeekStart = _mondayOf(DateTime.now());
      } else {
        final now = DateTime.now();
        _calendarMonth = DateTime(now.year, now.month);
      }
    });
    _load();
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<PlannedWorkout> _plannedOn(DateTime day) =>
      _planned.where((p) => p.plannedDate != null && _isSameDay(p.plannedDate!, day)).toList();

  List<Activity> _activitiesOn(DateTime day) =>
      _activities.where((a) => a.startDate != null && _isSameDay(a.startDate!, day)).toList();

  Future<void> _createSession(_SessionDraft draft, {DateTime? day}) async {
    try {
      await _repository.createPlanned(
        templateId: draft.templateId,
        date: day,
        name: draft.name,
        sportType: draft.sportType,
        durationMin: draft.durationMin,
        zone: draft.zone,
        keepAsTemplate: draft.keepAsTemplate,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de la création ($e)')));
      }
    }
  }

  /// Placement par drag-and-drop d'une séance du pool sur un jour.
  Future<void> _placeFromPool(PlannedWorkout item, DateTime day) async {
    try {
      await _repository.updatePlannedDate(item.id, day);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec du placement ($e)')));
      }
    }
  }

  /// Fait défiler la liste/grille active quand le doigt approche du haut ou du
  /// bas du viewport pendant un drag — la cible peut être hors écran (semaine
  /// suivante, jour plus bas) puisque le pool peut contenir plusieurs séances.
  void _handleDragUpdate(DragUpdateDetails details) {
    final key = _view == _PlanningView.plans ? _plansListKey : _calendarScrollKey;
    final controller = _view == _PlanningView.plans ? _plansScrollController : _calendarScrollController;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !controller.hasClients) return;

    final local = box.globalToLocal(details.globalPosition);
    const edge = 72.0;
    const step = 14.0;
    double? direction;
    if (local.dy >= 0 && local.dy < edge) {
      direction = -1;
    } else if (local.dy <= box.size.height && local.dy > box.size.height - edge) {
      direction = 1;
    }

    _autoScrollTimer?.cancel();
    if (direction == null) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!controller.hasClients) return;
      final target = (controller.offset + direction! * step).clamp(0.0, controller.position.maxScrollExtent);
      controller.jumpTo(target);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  Future<void> _confirmAndRemove(PlannedWorkout planned) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retirer "${planned.templateName}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.removePlanned(planned.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de la suppression ($e)')));
      }
    }
  }

  Future<void> _linkActivity(PlannedWorkout planned, Activity activity) async {
    try {
      await _repository.matchActivity(planned.id, activity.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de la liaison ($e)')));
      }
    }
  }

  /// Le matching auto ne peut pas trancher quand plusieurs activités du même
  /// jour partagent le sport de la séance planifiée — l'utilisateur choisit.
  Future<void> _openMatchPicker(PlannedWorkout planned, List<Activity> candidates) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activity = await showModalBottomSheet<Activity>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Lier "${planned.templateName}" à quelle activité ?',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            for (final a in candidates)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(context, a),
                  child: _CalendarDaySheetRow.activity(a, isDark: isDark),
                ),
              ),
          ],
        ),
      ),
    );
    if (activity != null) await _linkActivity(planned, activity);
  }

  Future<void> _openDaySheet(DateTime day) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final merge = _mergeDay(_plannedOn(day), _activitiesOn(day));
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _capitalize(_dayLabelFormat.format(day)),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            if (merge.unmatchedPlanned.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...merge.unmatchedPlanned.map((p) {
                final candidates = _matchCandidates(p, merge.unmatchedActivities);
                return _SheetPlannedRow(
                  planned: p,
                  onDelete: () {
                    Navigator.pop(context);
                    _confirmAndRemove(p);
                  },
                  onLink: candidates.length > 1
                      ? () {
                          Navigator.pop(context);
                          _openMatchPicker(p, candidates);
                        }
                      : null,
                );
              }),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openCreateSessionSheet(day: day);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter une séance'),
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre le sheet de création (template existant ou "from scratch"). Sans
  /// [day] (déclenché depuis le + de l'AppBar/FAB), la séance créée n'a pas de
  /// date et atterrit dans le pool — l'utilisateur la place ensuite par
  /// drag-and-drop ou en tapant un jour.
  Future<void> _openCreateSessionSheet({DateTime? day}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final draft = await showModalBottomSheet<_SessionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      builder: (context) => _CreateSessionSheet(templates: _templates),
    );
    if (draft != null) await _createSession(draft, day: day);
  }

  String _weekRangeLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return '${_dayMonthFormat.format(weekStart)} – ${_dayMonthFormat.format(weekEnd)}';
  }

  /// Vue Calendrier : pas de suppression depuis ici (seulement dans le sheet
  /// de la vue Plans) — mais on y résout le matching ambigu ("Lier une
  /// activité") puisque c'est là que planifié et réalisé sont listés ensemble.
  Future<void> _openCalendarDaySheet(DateTime day) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;
    final merge = _mergeDay(_plannedOn(day), _activitiesOn(day));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _capitalize(_dayLabelFormat.format(day)),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (merge.matched.isEmpty && merge.unmatchedPlanned.isEmpty && merge.unmatchedActivities.isEmpty)
              Text('Aucune séance', style: TextStyle(fontSize: 13, color: inkSecondary))
            else ...[
              for (final (_, a) in merge.matched) _CalendarDaySheetRow.activity(a, isDark: isDark),
              for (final a in merge.unmatchedActivities) _CalendarDaySheetRow.activity(a, isDark: isDark),
              for (final p in merge.unmatchedPlanned) _calendarPlannedRow(p, merge.unmatchedActivities),
            ],
          ],
        ),
      ),
    );
  }

  /// Carte d'une séance planifiée non matchée (vue Plans) — bascule sur un
  /// bouton "Lier" à la place du badge de zone quand le matching auto est
  /// ambigu (plusieurs activités candidates ce jour-là).
  Widget _plansPlannedCard(PlannedWorkout planned, List<Activity> unmatchedActivities, DateTime day) {
    final candidates = _matchCandidates(planned, unmatchedActivities);
    if (candidates.length <= 1) {
      return _SessionCard.planned(planned, onTap: () => _openDaySheet(day));
    }
    final sport = SportStyle.of(planned.sportType ?? '');
    final details = [
      if (planned.durationMin != null) '${planned.durationMin} min',
      if (planned.zone != null) planned.zone!,
    ].join(' · ');
    return _SessionCard(
      icon: sport.icon,
      iconColor: AppColors.zoneColor(planned.zone),
      title: planned.templateName,
      subtitle: '${sport.label}${details.isNotEmpty ? ' · $details' : ''}',
      trailing: TextButton(onPressed: () => _openMatchPicker(planned, candidates), child: const Text('Lier')),
      onTap: () => _openDaySheet(day),
    );
  }

  Widget _calendarPlannedRow(PlannedWorkout planned, List<Activity> unmatchedActivities) {
    final candidates = _matchCandidates(planned, unmatchedActivities);
    return _CalendarDaySheetRow.planned(
      planned,
      onLink: candidates.length > 1
          ? () {
              Navigator.pop(context);
              _openMatchPicker(planned, candidates);
            }
          : null,
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        actions: [
          TextButton(onPressed: _jumpToToday, child: const Text("Aujourd'hui")),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_PlanningView>(
              segments: const [
                ButtonSegment(value: _PlanningView.plans, label: Text('Plans'), icon: Icon(Icons.view_agenda_outlined)),
                ButtonSegment(
                  value: _PlanningView.calendar,
                  label: Text('Calendrier'),
                  icon: Icon(Icons.calendar_month_outlined),
                ),
              ],
              selected: {_view},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _switchView(selection.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                foregroundColor: inkSecondary,
                selectedBackgroundColor: accent,
                selectedForegroundColor: Colors.white,
                side: BorderSide.none,
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _view == _PlanningView.plans
                        ? _buildPlansView()
                        : _buildCalendarView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateSessionSheet(),
        tooltip: 'Ajouter une séance',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Liste chronologique, scrollable de haut en bas, groupée par semaine puis
  /// par jour — reprend le même découpage S-1..S+2 que l'ancienne grille.
  Widget _buildPlansView() {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    // Les 7 jours de chaque semaine sont toujours rendus (même vides) : chacun doit
    // exister comme cible de drop pour une séance glissée depuis le pool.
    final weeks = List.generate(_weeksShown, (w) {
      final weekStart = _anchorWeekStart.add(Duration(days: w * 7));
      final days = List.generate(
        7,
        (d) => (day: weekStart.add(Duration(days: d)), planned: <PlannedWorkout>[], activities: <Activity>[]),
      ).map((e) => (day: e.day, planned: _plannedOn(e.day), activities: _activitiesOn(e.day))).toList();
      return (weekStart: weekStart, days: days);
    });

    return Column(
      children: [
        _NavHeader(
          label: _capitalize(_monthFormat.format(_anchorWeekStart)),
          onPrev: () => _shiftWeeks(-1),
          onNext: () => _shiftWeeks(1),
        ),
        _PoolTray(items: _pool, onDragUpdate: _handleDragUpdate, onDragEnd: _stopAutoScroll),
        Expanded(
          child: ListView(
            key: _plansListKey,
            controller: _plansScrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              for (final week in weeks) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 10),
                  child: Text(
                    _weekRangeLabel(week.weekStart).toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: inkSecondary),
                  ),
                ),
                for (final entry in week.days)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlansDayDropZone(
                      onDrop: (item) => _placeFromPool(item, entry.day),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _capitalize(_dayLabelFormat.format(entry.day)),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _isSameDay(entry.day, now) ? accent : null,
                                ),
                              ),
                              if (_isSameDay(entry.day, now)) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Aujourd'hui",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final merge = _mergeDay(entry.planned, entry.activities);
                              if (merge.matched.isEmpty &&
                                  merge.unmatchedPlanned.isEmpty &&
                                  merge.unmatchedActivities.isEmpty) {
                                return _EmptyDayPlaceholder(isDark: isDark);
                              }
                              return Column(
                                children: [
                                  for (final (_, a) in merge.matched)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _SessionCard.activity(a, isDark: isDark),
                                    ),
                                  for (final a in merge.unmatchedActivities)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _SessionCard.activity(a, isDark: isDark),
                                    ),
                                  for (final p in merge.unmatchedPlanned)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _plansPlannedCard(p, merge.unmatchedActivities, entry.day),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarView() {
    final gridStart = _calendarGridStart;
    final totalDays = _calendarGridEnd.difference(gridStart).inDays + 1;
    final weeks = totalDays ~/ 7;
    final gridDays = List<DateTime>.generate(totalDays, (i) => gridStart.add(Duration(days: i)));
    final now = DateTime.now();

    return Column(
      children: [
        _NavHeader(
          label: _capitalize(_monthFormat.format(_calendarMonth)),
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
        ),
        _PoolTray(items: _pool, onDragUpdate: _handleDragUpdate, onDragEnd: _stopAutoScroll),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _WeekdayHeaderFluid()),
        const SizedBox(height: 6),
        Expanded(
          child: SingleChildScrollView(
            key: _calendarScrollKey,
            controller: _calendarScrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                for (var w = 0; w < weeks; w++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        for (final day in gridDays.sublist(w * 7, w * 7 + 7))
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _CalendarDayCell(
                                day: day,
                                isCurrentMonth: day.month == _calendarMonth.month,
                                isToday: _isSameDay(day, now),
                                planned: _plannedOn(day),
                                activities: _activitiesOn(day),
                                onTap: () => _openCalendarDaySheet(day),
                                onDrop: (item) => _placeFromPool(item, day),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bandeau de navigation mois/semaine — carte claire avec ombre douce, au même
/// niveau de finition que les autres cards (pas de bloc navy ici : réservé aux
/// cards de graphe du Dashboard).
class _NavHeader extends StatelessWidget {
  const _NavHeader({required this.label, required this.onPrev, required this.onNext});

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow(isDark),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: inkPrimary),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

/// Enrobe le bloc d'un jour (vue Plans) pour en faire une cible de drop —
/// même logique de surbrillance que [_CalendarDayCell] côté Calendrier.
class _PlansDayDropZone extends StatelessWidget {
  const _PlansDayDropZone({required this.onDrop, required this.child});

  final ValueChanged<PlannedWorkout> onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;

    return DragTarget<PlannedWorkout>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            color: isHovering ? accent.withValues(alpha: 0.08) : Colors.transparent,
            border: isHovering ? Border.all(color: accent, width: 1.5) : null,
          ),
          child: child,
        );
      },
    );
  }
}

/// Espace réservé pour un jour sans séance (vue Plans) — garde le jour visible
/// et cliquable comme cible de drop même quand il n'y a rien à afficher.
class _EmptyDayPlaceholder extends StatelessWidget {
  const _EmptyDayPlaceholder({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: inkSecondary.withValues(alpha: 0.2)),
      ),
      child: Text('Aucune séance', style: TextStyle(fontSize: 12, color: inkSecondary)),
    );
  }
}

/// En-tête des jours de la semaine, en colonnes fluides (pleine
/// largeur, sans scroll horizontal) pour la grille mensuelle.
class _WeekdayHeaderFluid extends StatelessWidget {
  const _WeekdayHeaderFluid();

  static const _labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;
    return Row(
      children: _labels
          .map(
            (l) => Expanded(
              child: Text(
                l.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: inkSecondary, letterSpacing: 0.4),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Carte de séance pour la liste chronologique de la vue Plans — même
/// gabarit que les cartes de la vue Activités (icône ronde, titre, sous-titre,
/// badge à droite) pour rester cohérent avec le reste de l'app.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  factory _SessionCard.activity(Activity a, {required bool isDark}) {
    final sport = SportStyle.of(a.sportType);
    final details = [
      if (a.distanceKm != null) '${a.distanceKm!.toStringAsFixed(1)} km',
      if (a.durationMin != null) '${a.durationMin!.toStringAsFixed(0)} min',
    ].join(' · ');
    return _SessionCard(
      icon: sport.icon,
      iconColor: sport.color(isDark),
      title: a.name,
      subtitle: '${sport.label}${details.isNotEmpty ? ' · $details' : ''}',
      trailing: a.chargeLoad != null ? _ChargeTrailing(chargeLoad: a.chargeLoad!) : null,
    );
  }

  factory _SessionCard.planned(PlannedWorkout p, {VoidCallback? onTap}) {
    final sport = SportStyle.of(p.sportType ?? '');
    final zoneColor = AppColors.zoneColor(p.zone);
    final details = [
      if (p.durationMin != null) '${p.durationMin} min',
      if (p.zone != null) p.zone!,
    ].join(' · ');
    return _SessionCard(
      icon: sport.icon,
      iconColor: zoneColor,
      title: p.templateName,
      subtitle: '${sport.label}${details.isNotEmpty ? ' · $details' : ''}',
      trailing: p.zone != null ? _ZoneTrailing(zone: p.zone!, color: zoneColor) : null,
      onTap: onTap,
    );
  }

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow(isDark),
      ),
      child: Material(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: inkSecondary),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Charge d'entraînement d'une activité terminée — même gabarit que dans la
/// vue Activités (valeur + légende "charge").
class _ChargeTrailing extends StatelessWidget {
  const _ChargeTrailing({required this.chargeLoad});

  final double chargeLoad;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          chargeLoad.toStringAsFixed(0),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accent),
        ),
        Text('charge', style: TextStyle(fontSize: 10, color: inkSecondary)),
      ],
    );
  }
}

/// Badge de zone d'intensité d'une séance planifiée.
class _ZoneTrailing extends StatelessWidget {
  const _ZoneTrailing({required this.zone, required this.color});

  final String zone;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(zone, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Case jour de la grille mensuelle "Calendrier". Hauteur fixe : au-delà de
/// [_maxVisibleSessions] séances, les suivantes sont résumées par un badge
/// "+N" pour ne jamais faire déborder la case.
class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.planned,
    required this.activities,
    required this.onTap,
    required this.onDrop,
  });

  final DateTime day;
  final bool isCurrentMonth;
  final bool isToday;
  final List<PlannedWorkout> planned;
  final List<Activity> activities;
  final VoidCallback onTap;
  final ValueChanged<PlannedWorkout> onDrop;

  static const _maxVisibleSessions = 3;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    final merge = _mergeDay(planned, activities);
    final sessions = [
      for (final (_, a) in merge.matched) _CalendarSession.fromActivity(a, isDark: isDark),
      for (final a in merge.unmatchedActivities) _CalendarSession.fromActivity(a, isDark: isDark),
      for (final p in merge.unmatchedPlanned) _CalendarSession.fromPlanned(p),
    ];
    final showDetail = sessions.length <= 2; // peu de séances -> ajoute durée/distance
    final overflowCount = sessions.length > _maxVisibleSessions ? sessions.length - (_maxVisibleSessions - 1) : 0;
    final shown = overflowCount > 0 ? sessions.sublist(0, _maxVisibleSessions - 1) : sessions;

    return SizedBox(
      height: 92,
      child: DragTarget<PlannedWorkout>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => onDrop(details.data),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: AppTheme.cellShadow(isDark)),
            child: Material(
              color: isHovering
                  ? accent.withValues(alpha: 0.14)
                  : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: isToday || isHovering ? Border.all(color: accent, width: 1.5) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isToday ? accent : (isCurrentMonth ? inkSecondary : AppColors.inkMuted),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: ClipRect(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final s in shown)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: _CalendarSessionChip(session: s, showDetail: showDetail),
                                ),
                              if (overflowCount > 0)
                                Text(
                                  '+$overflowCount',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: inkSecondary),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarSession {
  const _CalendarSession({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
    required this.background,
  });

  factory _CalendarSession.fromActivity(Activity a, {required bool isDark}) {
    final sport = SportStyle.of(a.sportType);
    final sportColor = sport.color(isDark);
    return _CalendarSession(
      icon: sport.icon,
      color: sportColor,
      label: sport.label,
      detail: a.distanceKm != null ? '${a.distanceKm!.toStringAsFixed(1)} km' : null,
      background: sportColor.withValues(alpha: 0.15),
    );
  }

  factory _CalendarSession.fromPlanned(PlannedWorkout p) {
    final sport = SportStyle.of(p.sportType ?? '');
    final zoneColor = AppColors.zoneColor(p.zone);
    return _CalendarSession(
      icon: sport.icon,
      color: zoneColor,
      label: p.zone ?? p.templateName,
      detail: p.durationMin != null ? "${p.durationMin}'" : null,
      background: zoneColor.withValues(alpha: 0.15),
    );
  }

  final IconData icon;
  final Color color;
  final String label;
  final String? detail;
  final Color background;
}

class _CalendarSessionChip extends StatelessWidget {
  const _CalendarSessionChip({required this.session, required this.showDetail});

  final _CalendarSession session;
  final bool showDetail;

  @override
  Widget build(BuildContext context) {
    final text =
        showDetail && session.detail != null ? '${session.label} · ${session.detail}' : session.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: session.background, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(session.icon, size: 9, color: session.color),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: session.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetPlannedRow extends StatelessWidget {
  const _SheetPlannedRow({required this.planned, required this.onDelete, this.onLink});

  final PlannedWorkout planned;
  final VoidCallback onDelete;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zoneColor = AppColors.zoneColor(planned.zone);
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;
    final pageColor = isDark ? AppColors.pageDark : AppColors.pageLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pageColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: zoneColor, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(planned.templateName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  [
                    if (planned.durationMin != null) '${planned.durationMin} min',
                    if (planned.zone != null) planned.zone!,
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: inkSecondary),
                ),
              ],
            ),
          ),
          if (onLink != null)
            TextButton(onPressed: onLink, child: const Text('Lier', style: TextStyle(fontSize: 12))),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 16),
            color: inkSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Ligne read-only pour la feuille de détail de la vue Calendrier (pas de
/// suppression ni de placement — voir [_PlanningScreenState._openCalendarDaySheet]).
class _CalendarDaySheetRow extends StatelessWidget {
  const _CalendarDaySheetRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  factory _CalendarDaySheetRow.activity(Activity a, {required bool isDark}) {
    final sport = SportStyle.of(a.sportType);
    final subtitle = [
      if (a.distanceKm != null) '${a.distanceKm!.toStringAsFixed(1)} km',
      if (a.chargeLoad != null) 'charge ${a.chargeLoad!.toStringAsFixed(0)}',
    ].join(' · ');
    return _CalendarDaySheetRow(icon: sport.icon, color: sport.color(isDark), title: a.name, subtitle: subtitle);
  }

  factory _CalendarDaySheetRow.planned(PlannedWorkout p, {VoidCallback? onLink}) {
    final sport = SportStyle.of(p.sportType ?? '');
    final zoneColor = AppColors.zoneColor(p.zone);
    final subtitle = [
      if (p.durationMin != null) '${p.durationMin} min',
      if (p.zone != null) p.zone!,
    ].join(' · ');
    return _CalendarDaySheetRow(
      icon: sport.icon,
      color: zoneColor,
      title: p.templateName,
      subtitle: subtitle,
      trailing: onLink != null
          ? TextButton(onPressed: onLink, child: const Text('Lier', style: TextStyle(fontSize: 12)))
          : null,
    );
  }

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;
    final pageColor = isDark ? AppColors.pageDark : AppColors.pageLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pageColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 11, color: inkSecondary)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});

  final WorkoutTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sport = SportStyle.of(template.sportType ?? '');
    final sportColor = sport.color(isDark);
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;
    final zoneColor = AppColors.zoneColor(template.zone);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? AppColors.pageDark : AppColors.pageLight,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: zoneColor, width: 3))),
            child: Row(
              children: [
                Icon(sport.icon, color: sportColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (template.durationMin != null || template.zone != null)
                        Text(
                          [
                            if (template.durationMin != null) '${template.durationMin} min',
                            if (template.zone != null) template.zone!,
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: inkSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Résultat du sheet de création : soit un template existant (`templateId`),
/// soit les champs libres d'une séance "from scratch".
class _SessionDraft {
  const _SessionDraft.template(this.templateId)
      : name = null,
        sportType = null,
        durationMin = null,
        zone = null,
        keepAsTemplate = false;

  const _SessionDraft.scratch({
    required this.name,
    required this.sportType,
    required this.durationMin,
    required this.zone,
    required this.keepAsTemplate,
  }) : templateId = null;

  final int? templateId;
  final String? name;
  final String? sportType;
  final int? durationMin;
  final String? zone;
  final bool keepAsTemplate;
}

enum _CreateTab { template, scratch }

/// Sheet de création de séance — deux onglets : "Template" (liste existante,
/// inchangée) et "From scratch" (petit formulaire). Le résultat remonte via
/// `Navigator.pop` ; c'est l'appelant qui décide de la date (jour tapé, ou
/// aucune -> la séance va dans le pool et se place ensuite par drag-and-drop).
class _CreateSessionSheet extends StatefulWidget {
  const _CreateSessionSheet({required this.templates});

  final List<WorkoutTemplate> templates;

  @override
  State<_CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<_CreateSessionSheet> {
  _CreateTab _tab = _CreateTab.template;
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  String _sportType = _scratchSportOptions.first.$1;
  String _zone = 'Z2';
  bool _keepAsTemplate = false;

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _submitScratch() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _SessionDraft.scratch(
        name: name,
        sportType: _sportType,
        durationMin: int.tryParse(_durationController.text.trim()),
        zone: _zone,
        keepAsTemplate: _keepAsTemplate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ajouter une séance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              SegmentedButton<_CreateTab>(
                segments: const [
                  ButtonSegment(value: _CreateTab.template, label: Text('Template')),
                  ButtonSegment(value: _CreateTab.scratch, label: Text('From scratch')),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => setState(() => _tab = selection.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.pageDark : AppColors.pageLight,
                  foregroundColor: inkSecondary,
                  selectedBackgroundColor: accent,
                  selectedForegroundColor: Colors.white,
                  side: BorderSide.none,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(height: 16),
              if (_tab == _CreateTab.template)
                if (widget.templates.isEmpty)
                  Text('Aucun template disponible', style: TextStyle(fontSize: 13, color: inkSecondary))
                else
                  ...widget.templates.map(
                    (t) => _TemplateTile(template: t, onTap: () => Navigator.pop(context, _SessionDraft.template(t.id))),
                  )
              else ...[
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom de la séance')),
                const SizedBox(height: 14),
                Text('Sport', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: inkSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in _scratchSportOptions)
                      ChoiceChip(
                        label: Text(option.$2),
                        avatar: Icon(option.$3, size: 16),
                        selected: _sportType == option.$1,
                        onSelected: (_) => setState(() => _sportType = option.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Durée (min)'),
                ),
                const SizedBox(height: 14),
                Text('Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: inkSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final z in _zoneOptions)
                      ChoiceChip(label: Text(z), selected: _zone == z, onSelected: (_) => setState(() => _zone = z)),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _keepAsTemplate,
                  onChanged: (v) => setState(() => _keepAsTemplate = v ?? false),
                  title: const Text('Garder comme template réutilisable', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _submitScratch, child: const Text('Créer')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau "séances à placer" — pool des séances créées sans date. Masqué
/// entièrement quand il est vide pour ne pas prendre de place inutilement.
class _PoolTray extends StatelessWidget {
  const _PoolTray({required this.items, required this.onDragUpdate, required this.onDragEnd});

  final List<PlannedWorkout> items;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Séances à placer · glisser sur un jour'.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: inkSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) =>
                  _PoolChip(item: items[i], onDragUpdate: onDragUpdate, onDragEnd: onDragEnd),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte source du drag — appui long pour initier (évite les conflits avec le
/// scroll/tap des listes et grilles sous-jacentes).
class _PoolChip extends StatelessWidget {
  const _PoolChip({required this.item, required this.onDragUpdate, required this.onDragEnd});

  final PlannedWorkout item;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = _PoolChipCard(item: item, isDark: isDark);
    return LongPressDraggable<PlannedWorkout>(
      data: item,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => onDragEnd(),
      feedback: Material(color: Colors.transparent, child: SizedBox(width: 140, child: Opacity(opacity: 0.9, child: card))),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }
}

class _PoolChipCard extends StatelessWidget {
  const _PoolChipCard({required this.item, required this.isDark});

  final PlannedWorkout item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final sport = SportStyle.of(item.sportType ?? '');
    final zoneColor = AppColors.zoneColor(item.zone);
    final inkSecondary = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(isDark),
        border: Border(left: BorderSide(color: zoneColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(sport.icon, size: 14, color: sport.color(isDark)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.templateName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [if (item.durationMin != null) '${item.durationMin} min', if (item.zone != null) item.zone!].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: inkSecondary),
          ),
        ],
      ),
    );
  }
}
