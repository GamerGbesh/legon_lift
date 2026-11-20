// Owner: WS4. Root widget: MaterialApp, theme and the onboarding gate (SPEC 3.3 step 6).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/models/models.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../state/profile_store.dart';
import '../state/settings_store.dart';
import 'routes.dart';
import 'shell.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

class LegonLiftApp extends StatelessWidget {
  const LegonLiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>().settings;
    final onboarded = context.select<ProfileStore, bool>((s) => s.profile != null);
    return MaterialApp(
      title: 'Legon Lift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(ColorTokens.light(settings.palette), brightness: Brightness.light),
      darkTheme: AppTheme.build(ColorTokens.dark(settings.palette)),
      themeMode: switch (settings.themeMode) {
        ThemeModePref.dark => ThemeMode.dark,
        ThemeModePref.light => ThemeMode.light,
        ThemeModePref.system => ThemeMode.system,
      },
      builder: (context, child) {
        if (!settings.largeText) return child!;
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * 1.15)),
          child: child!,
        );
      },
      home: onboarded ? const Shell() : const OnboardingFlow(),
      onGenerateRoute: onGenerateRoute,
    );
  }
}
