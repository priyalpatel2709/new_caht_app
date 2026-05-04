import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Theme mode (persisted in memory for this session).
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void setMode(ThemeMode mode) => state = mode;

  void toggle(BuildContext context) {
    final platform = MediaQuery.platformBrightnessOf(context);
    switch (state) {
      case ThemeMode.light:
        state = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        state = ThemeMode.light;
        break;
      case ThemeMode.system:
        state =
            platform == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
        break;
    }
  }
}

/// Bumps on every Supabase auth event so [GoRouter] re-runs [redirect].
final authRefreshListenableProvider = Provider<ValueNotifier<int>>((ref) {
  final n = ValueNotifier(0);
  final sub =
      Supabase.instance.client.auth.onAuthStateChange.listen((_) => n.value++);
  ref.onDispose(() {
    sub.cancel();
    n.dispose();
  });
  return n;
});
