import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1100),
    );
    final fadeAnim = useMemoized(
      () => CurvedAnimation(
        parent: controller,
        curve: const Interval(0, 0.55, curve: Curves.easeOut),
      ),
      [controller],
    );
    final scaleAnim = useMemoized(
      () => Tween<double>(begin: 0.88, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      ),
      [controller],
    );

    useEffect(() {
      controller.forward();
      return null;
    }, [controller]);

    useEffect(() {
      var cancelled = false;
      Future<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        if (!context.mounted || cancelled) return;
        final loggedIn =
            Supabase.instance.client.auth.currentSession != null;
        context.go(loggedIn ? '/home' : '/login');
      });
      return () => cancelled = true;
    }, const []);

    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.scaffoldBackgroundColor,
              AppColors.primary.withValues(alpha: 0.12),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: fadeAnim,
            child: ScaleTransition(
              scale: scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF7C89F6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Superbase',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Messages, groups, rooms',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
