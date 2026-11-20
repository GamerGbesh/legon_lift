// Owner: WS1. Settings (SPEC 4.12). Every change is saved immediately.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/app_info.dart';
import '../../core/format.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../services/api.dart';
import '../../state/profile_store.dart';
import '../../state/settings_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/number_stepper.dart';
import '../../widgets/section_header.dart';
import '../backup/data_actions.dart';
import 'equipment_screen.dart';
import 'widgets/reset_sheet.dart';

/// Units, equipment, workout, feedback, reminders, appearance, data and about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final s = store.settings;
    final profileStore = context.watch<ProfileStore>();
    final profile = profileStore.profile;
    final gym = context.read<AssetCatalog>().personalization.gym;

    void set(AppSettings next) => unawaited(store.update(next));
    void setProfile(UserProfile next) => unawaited(profileStore.save(next));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
        children: [
          if (profile != null) ...[
            const SectionHeader('Units'),
            _Choice<bool>(
              label: 'Weight',
              value: profile.useLb,
              options: const {false: 'kg', true: 'lb'},
              onChanged: (lb) => setProfile(profile.copyWith(useLb: lb)),
            ),
            _Choice<bool>(
              label: 'Height',
              value: profile.useFtIn,
              options: const {false: 'cm', true: 'ft + in'},
              onChanged: (ftIn) => setProfile(profile.copyWith(useFtIn: ftIn)),
            ),
          ],
          const SectionHeader('Equipment'),
          _NavTile(
            icon: Icons.fitness_center,
            title: 'Gym equipment',
            subtitle: _equipmentSummary(s.equipment, gym),
            onTap: () => Navigator.of(context).push(EquipmentScreen.route()),
          ),
          const SectionHeader('Workout'),
          _RestStepper(
            label: 'Rest after big lifts',
            seconds: s.restCompoundSec,
            onChanged: (sec) => set(s.copyWith(restCompoundSec: sec)),
          ),
          _RestStepper(
            label: 'Rest after small lifts',
            seconds: s.restIsolationSec,
            onChanged: (sec) => set(s.copyWith(restIsolationSec: sec)),
          ),
          _Switch(
            title: 'Start the rest timer after each set',
            value: s.autoRest,
            onChanged: (v) => set(s.copyWith(autoRest: v)),
          ),
          _Choice<RirPrompt>(
            label: 'Ask "How many more could you have done?"',
            value: s.rirPrompt,
            options: const {RirPrompt.every: 'Every set', RirPrompt.last: 'Last set', RirPrompt.never: 'Never'},
            onChanged: (v) => set(s.copyWith(rirPrompt: v)),
          ),
          _Switch(
            title: 'Warm-up sets before heavy lifts',
            subtitle: 'Lighter sets that prepare your joints.',
            value: s.warmupSets,
            onChanged: (v) => set(s.copyWith(warmupSets: v)),
          ),
          _Switch(
            title: 'Warm-up at the start',
            subtitle: 'Easy cardio and mobility before the first exercise.',
            value: s.warmupBlock,
            onChanged: (v) => set(s.copyWith(warmupBlock: v)),
          ),
          _Switch(
            title: 'Cool-down stretches at the end',
            value: s.cooldownBlock,
            onChanged: (v) => set(s.copyWith(cooldownBlock: v)),
          ),
          _Switch(
            title: '"Sip water" reminders',
            subtitle: 'Between exercises and while you rest.',
            value: s.hydrationNudges,
            onChanged: (v) => set(s.copyWith(hydrationNudges: v)),
          ),
          _Switch(
            title: 'Suggest "Hot today" from 11:00 to 17:00',
            subtitle: 'Hot days get a little more rest and more water breaks.',
            value: s.hotDayAuto,
            onChanged: (v) => set(s.copyWith(hotDayAuto: v)),
          ),
          const SectionHeader('Sound and vibration'),
          _Switch(title: 'Beeps', value: s.sound, onChanged: (v) => set(s.copyWith(sound: v))),
          _Switch(title: 'Vibration', value: s.vibration, onChanged: (v) => set(s.copyWith(vibration: v))),
          _Switch(
            title: 'Rest timer notification',
            subtitle: 'Tells you when rest is over, even with the phone locked.',
            value: s.restNotification,
            onChanged: (v) => set(s.copyWith(restNotification: v)),
          ),
          _Switch(
            title: 'Keep the screen on during workouts',
            value: s.keepAwake,
            onChanged: (v) => set(s.copyWith(keepAwake: v)),
          ),
          if (profile != null) ...[
            const SectionHeader('Reminders'),
            _Reminders(settings: s, profile: profile),
          ],
          const SectionHeader('Appearance'),
          _Choice<ThemeModePref>(
            label: 'Theme',
            value: s.themeMode,
            options: const {
              ThemeModePref.dark: 'Dark',
              ThemeModePref.light: 'Light',
              ThemeModePref.system: 'Phone',
            },
            onChanged: (v) => set(s.copyWith(themeMode: v)),
          ),
          const SizedBox(height: Space.m),
          _PalettePicker(value: s.palette, onChanged: (v) => set(s.copyWith(palette: v))),
          _Switch(
            title: 'Larger text',
            value: s.largeText,
            onChanged: (v) => set(s.copyWith(largeText: v)),
          ),
          const SectionHeader('Your data'),
          _NavTile(
            icon: Icons.backup,
            title: 'Backup and restore',
            subtitle: 'Save a copy of everything you logged.',
            onTap: () => Navigator.of(context).pushNamed(Routes.backup),
          ),
          const SizedBox(height: Space.s),
          BigButton(
            label: 'Reset all data',
            icon: Icons.delete_forever,
            kind: BigButtonKind.destructive,
            height: Sizes.minTap,
            onPressed: () => unawaited(_reset(context)),
          ),
          const SectionHeader('About'),
          _About(disclaimer: context.read<AssetCatalog>().personalization.raw['disclaimer']),
        ],
      ),
    );
  }

  static String _equipmentSummary(EquipmentProfile eq, GymProfileDefaults gym) {
    final unknown = [
      if (eq.has(Equipment.smithMachine) && !eq.smithBarKnown) 'Smith bar',
      if (eq.has(Equipment.legPress) && !eq.legPressSledKnown) 'leg press sled',
    ];
    final ticked = '${eq.available.length} ${eq.available.length == 1 ? 'item' : 'items'} ticked';
    return unknown.isEmpty ? ticked : '$ticked · weight unknown: ${unknown.join(', ')}';
  }

  static Future<void> _reset(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const ResetSheet(),
    );
    if (confirmed != true || !context.mounted) return;
    final actions = DataActions.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await actions.resetAll();
    } on Object catch (e, st) {
      debugPrint('Reset failed: $e\n$st');
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not save a safety copy first, so nothing was erased. Free some storage and try again.'),
      ));
      return;
    }
    // The profile is gone, so the app's home is onboarding again: show it.
    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(const SnackBar(
      content: Text('All data erased. A safety copy is in Backup > Automatic backups.'),
    ));
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.title, this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: Sizes.minTap,
      title: Text(title, style: AppText.body.copyWith(color: t.onSurface)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: AppText.label.copyWith(color: t.muted)),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A label above a full-width segmented choice (56 dp).
class _Choice<T extends Object> extends StatelessWidget {
  const _Choice({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppText.body.copyWith(color: t.onSurface)),
          const SizedBox(height: Space.s),
          SizedBox(
            height: Sizes.minTap,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final MapEntry(:key, :value) in options.entries) ButtonSegment<T>(value: key, label: Text(value)),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: Sizes.minTap,
      leading: Icon(icon, color: t.onSurface),
      title: Text(title, style: AppText.body.copyWith(color: t.onSurface)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: AppText.label.copyWith(color: t.muted)),
      trailing: Icon(Icons.chevron_right, color: t.muted),
      onTap: onTap,
    );
  }
}

class _RestStepper extends StatelessWidget {
  const _RestStepper({required this.label, required this.seconds, required this.onChanged});

  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.body.copyWith(color: t.onSurface))),
              Text(Fmt.clock(seconds), style: AppText.tabular(AppText.body).copyWith(color: t.muted)),
            ],
          ),
          NumberStepper(
            value: seconds.toDouble(),
            step: 15,
            min: 30,
            max: 300,
            decimals: 0,
            unit: 'sec',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

/// Workout days, workout reminder time, weigh-in time and the gym-bag reminder.
class _Reminders extends StatelessWidget {
  const _Reminders({required this.settings, required this.profile});

  final AppSettings settings;
  final UserProfile profile;

  static const String _defaultWorkoutTime = '16:00';
  static const String _defaultWeighInTime = '06:30';

  /// Saves [next], asking for notification permission first when a reminder is being turned on.
  Future<void> _apply(BuildContext context, AppSettings next, {bool turningOn = false}) async {
    final store = context.read<SettingsStore>();
    final profileStore = context.read<ProfileStore>();
    final messenger = ScaffoldMessenger.of(context);
    if (turningOn) {
      final allowed = await context.read<RestAlarm>().ensurePermission();
      if (!allowed) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Notifications are off for Legon Lift. Turn them on in the phone settings to get reminders.'),
        ));
      }
    }
    await store.update(next);
    await profileStore.syncReminders();
  }

  Future<String?> _pickTime(BuildContext context, String current) async {
    final picked = await showTimePicker(context: context, initialTime: _parse(current));
    return picked == null ? null : _format(picked);
  }

  static TimeOfDay _parse(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.tryParse(parts.first) ?? 0, minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = settings;
    final localizations = MaterialLocalizations.of(context);
    String shown(String hhmm) => localizations.formatTimeOfDay(_parse(hhmm));

    Widget timeRow({
      required String title,
      required String? time,
      required String defaultTime,
      required AppSettings Function(String? time) withTime,
    }) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Switch(
              title: title,
              value: time != null,
              onChanged: (on) => unawaited(_apply(context, withTime(on ? defaultTime : null), turningOn: on)),
            ),
            if (time != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: Sizes.minTap,
                leading: Icon(Icons.schedule, color: t.muted),
                title: Text('At ${shown(time)}', style: AppText.tabular(AppText.body).copyWith(color: t.onSurface)),
                trailing: Text('Change', style: AppText.label.copyWith(color: t.primary)),
                onTap: () async {
                  final picked = await _pickTime(context, time);
                  if (picked != null && context.mounted) await _apply(context, withTime(picked));
                },
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Workout days', style: AppText.body.copyWith(color: t.onSurface)),
        const SizedBox(height: Space.s),
        _WeekdayPicker(
          selected: profile.workoutWeekdays,
          onChanged: (days) => unawaited(
            context.read<ProfileStore>().save(profile.copyWith(workoutWeekdays: days, daysPerWeek: days.length)),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Your program stays the same. To change it, open the Program tab.',
          style: AppText.label.copyWith(color: t.muted),
        ),
        const SizedBox(height: Space.s),
        timeRow(
          title: 'Workout day reminder',
          time: s.reminderTime,
          defaultTime: _defaultWorkoutTime,
          withTime: (v) => s.copyWith(reminderTime: () => v),
        ),
        timeRow(
          title: 'Weigh-in reminder',
          time: s.weighInTime,
          defaultTime: _defaultWeighInTime,
          withTime: (v) => s.copyWith(weighInTime: () => v),
        ),
        _Switch(
          title: 'Pack your gym bag (evening before)',
          value: s.gymBagReminder,
          onChanged: (on) => unawaited(_apply(context, s.copyWith(gymBagReminder: on), turningOn: on)),
        ),
      ],
    );
  }
}

/// Mon..Sun toggles, 56 dp tall. At least one day stays selected.
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          if (day > 1) const SizedBox(width: Space.xs),
          Expanded(
            child: Builder(builder: (context) {
              final on = selected.contains(day);
              final shape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.chip),
                side: BorderSide(color: on ? t.primary : t.surface2),
              );
              return Semantics(
                button: true,
                toggled: on,
                label: Fmt.weekdayShort(day),
                excludeSemantics: true,
                child: Material(
                  color: on ? t.primary : t.surface,
                  shape: shape,
                  child: InkWell(
                    customBorder: shape,
                    onTap: on && selected.length == 1
                        ? null
                        : () => onChanged(
                              (on ? selected.where((d) => d != day) : [...selected, day]).toSet().toList()..sort(),
                            ),
                    child: SizedBox(
                      height: Sizes.minTap,
                      child: Center(
                        child: Text(
                          Fmt.weekdayShort(day).substring(0, 2),
                          style: AppText.label.copyWith(color: on ? t.onPrimary : t.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PalettePicker extends StatelessWidget {
  const _PalettePicker({required this.value, required this.onChanged});

  final PaletteId value;
  final ValueChanged<PaletteId> onChanged;

  static String _name(PaletteId id) => switch (id) {
        PaletteId.legonNight => 'Legon Night',
        PaletteId.kenteEnergy => 'Kente Energy',
        PaletteId.voltTeal => 'Volt Teal',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Colours', style: AppText.body.copyWith(color: t.onSurface)),
        const SizedBox(height: Space.s),
        Row(
          children: [
            for (final id in PaletteId.values) ...[
              if (id != PaletteId.values.first) const SizedBox(width: Space.s),
              Expanded(child: _paletteCard(context, id)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _paletteCard(BuildContext context, PaletteId id) {
    final t = context.tokens;
    final p = ColorTokens.dark(id);
    final selected = id == value;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
      side: BorderSide(color: selected ? t.primary : t.surface2, width: selected ? 2 : 1),
    );
    Widget dot(Color c) => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: p.surface2)),
        );
    return Semantics(
      button: true,
      selected: selected,
      label: _name(id),
      excludeSemantics: true,
      child: Material(
        color: p.bg,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () => onChanged(id),
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [dot(p.primary), const SizedBox(width: Space.xs), dot(p.secondary), const SizedBox(width: Space.xs), dot(p.success)],
                ),
                const SizedBox(height: Space.s),
                Text(
                  _name(id),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: AppText.label.copyWith(color: p.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.disclaimer});

  final Object? disclaimer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final legal = disclaimer is String ? disclaimer! as String : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${AppInfo.name} ${AppInfo.version}', style: AppText.body.copyWith(color: t.onSurface)),
        const SizedBox(height: Space.xs),
        Text(
          'Your step-by-step coach for the UG gym. Works offline; your data stays on this phone.',
          style: AppText.label.copyWith(color: t.muted),
        ),
        if (legal.isNotEmpty) ...[
          const SizedBox(height: Space.m),
          Text(legal, style: AppText.label.copyWith(color: t.muted)),
        ],
        const SizedBox(height: Space.s),
        _NavTile(
          icon: Icons.description_outlined,
          title: 'Licences',
          onTap: () => showLicensePage(
            context: context,
            applicationName: AppInfo.name,
            applicationVersion: AppInfo.version,
            applicationLegalese: legal,
          ),
        ),
      ],
    );
  }
}
