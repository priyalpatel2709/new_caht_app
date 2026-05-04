import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/providers/service_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final loading = useState(false);

    Future<void> submit() async {
      loading.value = true;
      try {
        await ref.read(authServiceProvider).signIn(
              email: emailController.text.trim(),
              password: passwordController.text,
            );
        if (!context.mounted) return;
        context.go('/home');
      } on AuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } finally {
        loading.value = false;
      }
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Welcome back',
                style: theme.textTheme.displaySmall?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in with your Supabase account.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 40),
              InputField(
                controller: emailController,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                prefix: const Icon(Icons.mail_outline_rounded, size: 22),
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              InputField(
                controller: passwordController,
                label: 'Password',
                obscure: true,
                prefix: const Icon(Icons.lock_outline_rounded, size: 22),
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 28),
              CustomButton(
                label: 'Sign in',
                isLoading: loading.value,
                onPressed: loading.value ? null : submit,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: Divider(color: theme.dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Or continue with',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  Expanded(child: Divider(color: theme.dividerColor)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialChip(icon: Icons.g_mobiledata_rounded, label: 'Google'),
                  const SizedBox(width: 12),
                  _SocialChip(icon: Icons.apple, label: 'Apple'),
                  const SizedBox(width: 12),
                  _SocialChip(icon: Icons.chat_bubble_outline, label: 'Discord'),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New here?',
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.push('/signup'),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialChip extends StatelessWidget {
  const _SocialChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label is not wired yet')),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
