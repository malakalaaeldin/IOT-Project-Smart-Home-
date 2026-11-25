import 'package:flutter/material.dart';

import '../models/automation_settings.dart';
import '../models/schedule.dart';
import '../services/app_services.dart';
import '../widgets/state_views.dart';

/// Automation rules the ESP32 reads from Firebase (thresholds) and daily
/// schedules. Editing is for admins; normal users see the current values.
class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key, required this.services, required this.isAdmin});
  final AppServices services;
  final bool isAdmin;

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  late final Stream<AutomationSettings> _settings = widget.services.home.settings;
  late final Stream<List<Schedule>> _schedules = widget.services.home.schedules;
  AutomationSettings? _draft;
  bool _saving = false;

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      await widget.services.home.saveSettings(draft);
      _toast('Saved. The ESP32 applies it within 10 seconds.');
      setState(() => _draft = null);
    } catch (e) {
      _toast("Couldn't save: ${e.toString().contains('ermission') ? 'only admins can change automation' : e}");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addSchedule() async {
    var action = ScheduleAction.all.first;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Run every day at',
    );
    if (picked == null || !mounted) return;
    final chosen = await showDialog<ScheduleAction>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Every day at ${picked.format(ctx)}'),
          content: DropdownButton<ScheduleAction>(
            isExpanded: true,
            value: action,
            items: [
              for (final a in ScheduleAction.all)
                DropdownMenuItem(value: a, child: Text(a.label)),
            ],
            onChanged: (a) => setLocal(() => action = a ?? action),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, action), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    try {
      await widget.services.home.addSchedule(chosen, picked.hour, picked.minute);
      _toast('Schedule added.');
    } catch (e) {
      _toast("Couldn't add the schedule: $e");
    }
  }

  Widget _slider(String label, String value, double current, double min, double max,
      int divisions, ValueChanged<double>? onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.isAdmin;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!admin)
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: const ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('View only'),
              subtitle: Text('Ask an admin to change automation rules or schedules.'),
            ),
          ),
        Text('Automation rules', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('The ESP32 reads these from Firebase every 10 seconds.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        StreamBuilder<AutomationSettings>(
          stream: _settings,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error);
            if (!snap.hasData) return const LoadingView(message: 'Loading settings…');
            final s = _draft ?? snap.data!;
            void edit(AutomationSettings n) => setState(() => _draft = n);
            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _slider('Garage opens when a car is within', '${s.garageDetectCm} cm',
                        s.garageDetectCm.toDouble(), 3, 100, 97,
                        admin ? (v) => edit(s.copyWith(garageDetectCm: v.round())) : null),
                    _slider('Garage closes after the car leaves', '${s.garageCloseDelaySec} s',
                        s.garageCloseDelaySec.toDouble(), 1, 30, 29,
                        admin ? (v) => edit(s.copyWith(garageCloseDelaySec: v.round())) : null),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Clothes line reopens when dry'),
                      subtitle: const Text('Off: rain closes it and it stays closed'),
                      value: s.clothesLineFollowsRain,
                      onChanged: admin ? (v) => edit(s.copyWith(clothesLineFollowsRain: v)) : null,
                    ),
                    _slider('Save a history reading every', '${s.historyIntervalSec} s',
                        s.historyIntervalSec.toDouble(), 10, 300, 29,
                        admin ? (v) => edit(s.copyWith(historyIntervalSec: v.round())) : null),
                    if (admin)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_draft != null)
                            TextButton(
                              onPressed: () => setState(() => _draft = null),
                              child: const Text('Discard'),
                            ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _draft == null || _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'Saving…' : 'Save to ESP32'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('Schedules', style: theme.textTheme.titleMedium)),
            if (admin)
              FilledButton.tonalIcon(
                onPressed: _addSchedule,
                icon: const Icon(Icons.add_alarm),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Runs every day at the set time (the ESP32 keeps time over the internet).',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        StreamBuilder<List<Schedule>>(
          stream: _schedules,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error);
            if (!snap.hasData) return const LoadingView(message: 'Loading schedules…');
            final list = snap.data!;
            if (list.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('No schedules yet'),
                  subtitle: Text(admin
                      ? 'Tap Add, e.g. "Light 1 on at 19:00".'
                      : 'An admin can add daily actions here.'),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final sc in list)
                    ListTile(
                      leading: CircleAvatar(child: Text(sc.timeLabel.substring(0, 2))),
                      title: Text(sc.action.label),
                      subtitle: Text('Every day at ${sc.timeLabel}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: sc.enabled,
                            onChanged: admin
                                ? (v) => widget.services.home.setScheduleEnabled(sc.id, v)
                                : null,
                          ),
                          if (admin)
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => widget.services.home.deleteSchedule(sc.id),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
