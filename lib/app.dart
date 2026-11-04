import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/menu/presentation/menu_controller.dart';

/// Lifecycle resume rechecks real expiry, independent of background timers.
class BookixoApp extends ConsumerStatefulWidget {
  const BookixoApp({super.key});
  @override
  ConsumerState<BookixoApp> createState() => _BookixoAppState();
}

class _BookixoAppState extends ConsumerState<BookixoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    }
  }

  Future<void> _resume() async {
    await ref.read(authControllerProvider.notifier).resume();
    if (!mounted) return;
    await ref.read(menuControllerProvider.notifier).refresh(resume: true);
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppStrings.appName,
    theme: AppTheme.forBrightness(Brightness.light),
    darkTheme: AppTheme.forBrightness(Brightness.dark),
    routerConfig: ref.watch(routerProvider),
  );
}
