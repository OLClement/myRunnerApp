import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../auth/auth_repository.dart';
import 'settings.dart';
import 'settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repository = SettingsRepository();
  final _authRepository = AuthRepository();
  final _formKey = GlobalKey<FormState>();

  final _fcMaxController = TextEditingController();
  final _pr5kController = TextEditingController();
  final _pr10kController = TextEditingController();
  final _prSemiController = TextEditingController();
  final _prMarathonController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fcMaxController.dispose();
    _pr5kController.dispose();
    _pr10kController.dispose();
    _prSemiController.dispose();
    _prMarathonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await _repository.get();
      setState(() {
        _fcMaxController.text = settings.fcMax?.toString() ?? '';
        _pr5kController.text = _formatDuration(settings.pr5kSec);
        _pr10kController.text = _formatDuration(settings.pr10kSec);
        _prSemiController.text = _formatDuration(settings.prSemiSec);
        _prMarathonController.text = _formatDuration(settings.prMarathonSec);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repository.update(
        Settings(
          fcMax: int.tryParse(_fcMaxController.text),
          pr5kSec: _parseDuration(_pr5kController.text),
          pr10kSec: _parseDuration(_pr10kController.text),
          prSemiSec: _parseDuration(_prSemiController.text),
          prMarathonSec: _parseDuration(_prMarathonController.text),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réglages enregistrés')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de l\'enregistrement ($e)')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _formatDuration(int? totalSeconds) {
    if (totalSeconds == null) return '';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static int? _parseDuration(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    return minutes * 60 + seconds;
  }

  String? _validateDuration(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (_parseDuration(value) == null) return 'Format attendu : mm:ss';
    return null;
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (confirmed != true) return;

    await _authRepository.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _SettingsCard(
                          title: 'Fréquence cardiaque',
                          children: [
                            TextFormField(
                              controller: _fcMaxController,
                              decoration: const InputDecoration(labelText: 'FC max (bpm)'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SettingsCard(
                          title: 'Records personnels (mm:ss)',
                          children: [
                            TextFormField(
                              controller: _pr5kController,
                              decoration: const InputDecoration(labelText: '5 km'),
                              validator: _validateDuration,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pr10kController,
                              decoration: const InputDecoration(labelText: '10 km'),
                              validator: _validateDuration,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _prSemiController,
                              decoration: const InputDecoration(labelText: 'Semi-marathon'),
                              validator: _validateDuration,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _prMarathonController,
                              decoration: const InputDecoration(labelText: 'Marathon'),
                              validator: _validateDuration,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Enregistrer'),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _confirmAndLogout,
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.statusCritical),
                          child: const Text('Se déconnecter'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
