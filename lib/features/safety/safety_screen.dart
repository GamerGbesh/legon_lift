// Owner: WS6. Safety (SPEC 4.11): emergency numbers with tap-to-call, emergency contact, red
// flags, the 3/10 pain rule, heat illness and prevention, and the yearly PAR-Q re-check.
// Content comes from `personalization.safety`.
import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../services/api.dart';
import '../../state/profile_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/section_header.dart';
import 'parq_sheet.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final safety = context.read<AssetCatalog>().personalization.safety;
    final profile = context.watch<ProfileStore>().profile;
    final heat = [for (final h in _list(safety['heat_illness'])) if (h is Map) h.cast<String, Object?>()];
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
        children: [
          _EmergencyCard(emergency: _map(safety['emergency'])),
          const SectionHeader('Your emergency contact'),
          _ContactCard(profile: profile),
          const SectionHeader('Stop now and get help if you have'),
          _Card(children: [
            for (final f in _strings(safety['red_flags_stop_now']))
              _Line(text: f, icon: Icons.warning_amber_rounded, iconColor: context.tokens.danger),
          ]),
          const SectionHeader('Pain rule: 3 out of 10'),
          const _Card(children: [
            _Line(text: 'Mild discomfort up to 3 out of 10 that settles quickly is OK. Muscle burn while you lift is normal.'),
            _Line(text: 'Pain above 3, sharp pain, joint pain, or pain that gets worse as you go: stop that exercise.'),
            _Line(text: "In a workout, tap \"It hurts\" and the app offers an easier swap. If it still hurts the next day, rest it and get it checked."),
          ]),
          const SectionHeader('Heat illness'),
          for (final h in heat) Padding(padding: const EdgeInsets.only(bottom: Space.m), child: _HeatCard(item: h)),
          const SectionHeader('Beat the heat'),
          _Card(children: [for (final tip in _strings(safety['heat_prevention'])) _Line(text: tip, icon: Icons.wb_sunny_outlined)]),
          const SectionHeader('Yearly health check'),
          _ParqCard(profile: profile, parq: _map(safety['parq'])),
        ],
      ),
    );
  }
}

Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : const {};

List<Object?> _list(Object? v) => v is List ? v : const [];

List<String> _strings(Object? v) => [for (final x in _list(v)) if (x is String) x];

/// Opens the dialler; tells the user to dial by hand when that fails.
Future<void> _call(BuildContext context, String number) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await context.read<LauncherService>().call(number);
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open the phone app. Dial $number yourself.')));
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line({required this.text, this.icon = Icons.chevron_right, this.iconColor});

  final String text;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? t.muted),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: AppText.body.copyWith(color: t.onSurface))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Emergency

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.emergency});

  final Map<String, Object?> emergency;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final national = '${emergency['ghana_national'] ?? '112'}';
    final ambulance = '${emergency['ambulance'] ?? '193'}';
    final facility = '${emergency['nearest_facility'] ?? 'University of Ghana Hospital, Legon'}';
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: t.danger, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.emergency, color: t.danger, size: 28),
              const SizedBox(width: Space.s),
              Text('Emergency', style: AppText.headline.copyWith(color: t.onSurface)),
            ]),
            const SizedBox(height: Space.s),
            Text(
              'Someone collapsed, has chest pain, or is confused in the heat? Call now, then start cooling them.',
              style: AppText.body.copyWith(color: t.onSurface),
            ),
            const SizedBox(height: Space.l),
            BigButton(label: 'Call $national (emergency)', icon: Icons.call, onPressed: () => unawaited(_call(context, national))),
            const SizedBox(height: Space.s),
            BigButton(
              label: 'Call $ambulance (ambulance)',
              icon: Icons.local_hospital,
              kind: BigButtonKind.secondary,
              height: Sizes.heroButton,
              onPressed: () => unawaited(_call(context, ambulance)),
            ),
            const SizedBox(height: Space.m),
            Row(children: [
              Icon(Icons.place, color: t.muted, size: 20),
              const SizedBox(width: Space.s),
              Expanded(child: Text('Nearest: $facility', style: AppText.body.copyWith(color: t.onSurface))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = profile;
    final name = p?.emergencyName;
    final phone = p?.emergencyPhone;
    if (p == null) {
      return Text('Finish setting up the app to add an emergency contact.', style: AppText.body.copyWith(color: t.muted));
    }
    if (phone == null || phone.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Someone the gym staff can call for you. It stays on this phone.',
              style: AppText.body.copyWith(color: t.muted)),
          const SizedBox(height: Space.m),
          BigButton(
            label: 'Add emergency contact',
            icon: Icons.person_add,
            kind: BigButtonKind.secondary,
            height: Sizes.minTap,
            onPressed: () => unawaited(_editContact(context, p)),
          ),
        ],
      );
    }
    final who = (name == null || name.isEmpty) ? phone : name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.contact_phone, color: t.primary),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(who, style: AppText.title.copyWith(fontSize: 18, color: t.onSurface)),
                  if (who != phone) Text(phone, style: AppText.tabular(AppText.body).copyWith(color: t.muted)),
                ]),
              ),
              IconButton(
                tooltip: 'Edit contact',
                iconSize: 24,
                constraints: const BoxConstraints(minWidth: Sizes.minTap, minHeight: Sizes.minTap),
                onPressed: () => unawaited(_editContact(context, p)),
                icon: Icon(Icons.edit, color: t.muted),
              ),
            ]),
            const SizedBox(height: Space.m),
            BigButton(
              label: 'Call $who',
              icon: Icons.call,
              kind: BigButtonKind.secondary,
              height: Sizes.minTap,
              onPressed: () => unawaited(_call(context, phone)),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editContact(BuildContext context, UserProfile profile) async {
  final store = context.read<ProfileStore>();
  final name = TextEditingController(text: profile.emergencyName ?? '');
  final phone = TextEditingController(text: profile.emergencyPhone ?? '');
  final result = await showModalBottomSheet<({String? name, String? phone})>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ContactSheet(name: name, phone: phone, canRemove: profile.emergencyPhone != null),
  );
  name.dispose();
  phone.dispose();
  if (result == null) return;
  final current = store.profile ?? profile;
  await store.save(current.copyWith(emergencyName: () => result.name, emergencyPhone: () => result.phone));
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.name, required this.phone, required this.canRemove});

  final TextEditingController name, phone;
  final bool canRemove;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  static final _phoneChars = RegExp(r'^\+?[0-9 ]{6,20}$');

  bool get _valid => _phoneChars.hasMatch(widget.phone.text.trim());

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void save() {
      if (!_valid) return;
      final n = widget.name.text.trim();
      Navigator.of(context).pop((name: n.isEmpty ? null : n, phone: widget.phone.text.trim()));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Emergency contact', style: AppText.title.copyWith(color: t.onSurface)),
          const SizedBox(height: Space.l),
          TextField(
            controller: widget.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: AppText.body.copyWith(color: t.onSurface),
            decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'e.g. Ama (sister)'),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: widget.phone,
            keyboardType: TextInputType.phone,
            style: AppText.tabular(AppText.body).copyWith(color: t.onSurface),
            decoration: const InputDecoration(labelText: 'Phone number', hintText: 'e.g. 024 123 4567'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => save(),
          ),
          const SizedBox(height: Space.xl),
          BigButton(label: 'Save', onPressed: _valid ? save : null),
          if (widget.canRemove) ...[
            const SizedBox(height: Space.s),
            BigButton(
              label: 'Remove contact',
              kind: BigButtonKind.destructive,
              height: Sizes.minTap,
              onPressed: () => Navigator.of(context).pop((name: null, phone: null)),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Heat

class _HeatCard extends StatelessWidget {
  const _HeatCard({required this.item});

  final Map<String, Object?> item;

  static String _title(String id, String fallback) => switch (id) {
        'dehydration_cramps' => 'Dehydration and cramps',
        'heat_exhaustion' => 'Heat exhaustion',
        'heat_stroke' => 'Heat stroke',
        _ => fallback,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final severity = '${item['severity'] ?? ''}';
    final (color, badge) = switch (severity) {
      'emergency' => (t.danger, 'EMERGENCY'),
      'moderate' => (t.warning, 'SERIOUS'),
      _ => (t.success, 'MILD'),
    };
    final id = '${item['id'] ?? ''}';
    final signs = _strings(item['signs']);
    final action = item['action'];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: severity == 'emergency' ? color : t.surface2, width: severity == 'emergency' ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(_title(id, id.replaceAll('_', ' ')), style: AppText.title.copyWith(fontSize: 18, color: t.onSurface)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(Radii.chip)),
                child: Text(badge, style: AppText.label.copyWith(color: color, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: Space.s),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Signs: ', style: AppText.label.copyWith(color: t.muted)),
              TextSpan(text: signs.join(', '), style: AppText.body.copyWith(color: t.onSurface)),
            ])),
            if (action is String) ...[
              const SizedBox(height: Space.s),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Do this: ', style: AppText.label.copyWith(color: color)),
                TextSpan(text: action, style: AppText.body.copyWith(color: t.onSurface, fontWeight: FontWeight.w600)),
              ])),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// PAR-Q

class _ParqCard extends StatelessWidget {
  const _ParqCard({required this.profile, required this.parq});

  final UserProfile? profile;
  final Map<String, Object?> parq;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = profile;
    if (p == null) return const SizedBox.shrink();
    final months = (parq['re_ask_every_months'] as num?)?.toInt() ?? 12;
    final answered = p.parqAnsweredAt.toLocal();
    final due = DateTime(answered.year, answered.month + months, answered.day);
    final isDue = !context.read<Clock>().now().isBefore(due);
    final onYes = _map(parq['on_any_yes']);
    final fmt = DateFormat('d MMM yyyy');
    final advice = ghanaAdvice(p.ghanaAnswers, _list(parq['ghana_extra_questions']));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'A short set of health questions (based on the PAR-Q+). We ask again every $months months.',
              style: AppText.body.copyWith(color: t.onSurface),
            ),
            const SizedBox(height: Space.s),
            Text(
              'Last answered ${fmt.format(answered)}. ${isDue ? 'Time to answer again.' : 'Next: ${fmt.format(due)}.'}',
              style: AppText.label.copyWith(color: isDue ? t.warning : t.muted),
            ),
            if (p.programBlocked) ...[
              const SizedBox(height: Space.m),
              _Notice(text: '${onYes['message'] ?? 'Please talk to a doctor before starting.'}', color: t.warning),
              const SizedBox(height: Space.m),
              BigButton(
                label: '${onYes['ack_label'] ?? "I've been cleared by a doctor to exercise"}',
                kind: BigButtonKind.secondary,
                height: Sizes.heroButton,
                onPressed: () => unawaited(context.read<ProfileStore>().save(p.copyWith(parqCleared: true))),
              ),
            ],
            for (final a in advice) ...[const SizedBox(height: Space.m), _Notice(text: a, color: t.secondary)],
            const SizedBox(height: Space.l),
            BigButton(
              label: isDue ? 'Answer the health check' : 'Answer again',
              icon: Icons.fact_check,
              kind: isDue ? BigButtonKind.primary : BigButtonKind.secondary,
              height: Sizes.heroButton,
              onPressed: () => unawaited(showParqSheet(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(text, style: AppText.body.copyWith(color: context.tokens.onSurface)),
      );
}
