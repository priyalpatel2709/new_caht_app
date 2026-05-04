import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/providers/service_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';

class SignupScreen extends HookConsumerWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = useTextEditingController();
    final email = useTextEditingController();
    final password = useTextEditingController();
    final avatarBytes = useState<Uint8List?>(null);
    final loading = useState(false);
    useListenable(username);

    Future<void> pickAvatar() async {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (x == null) return;
      final b = await x.readAsBytes();
      avatarBytes.value = Uint8List.fromList(b);
    }

    Future<void> submit() async {
      final u = username.text.trim();
      final em = email.text.trim();
      final pw = password.text;
      if (u.isEmpty || em.isEmpty || pw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fill all fields')),
        );
        return;
      }

      loading.value = true;
      try {
        final auth = ref.read(authServiceProvider);
        final res = await auth.signUp(email: em, password: pw, username: u);
        if (!context.mounted) return;

        if (res.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check your email to confirm your account.'),
            ),
          );
          context.pop();
          return;
        }

        final uid = res.user?.id;
        if (uid != null && avatarBytes.value != null) {
          final storage = ref.read(storageServiceProvider);
          final client = ref.read(supabaseProvider);
          try {
            await storage.uploadUserAvatar(
              userId: uid,
              imageBytes: avatarBytes.value!,
            );
            final publicUrl = storage.getUserAvatarPublicUrl('$uid/avatar.jpg');
            await client.from('profiles').update({
              'avatar_url': publicUrl,
            }).eq('id', uid);
          } on StorageException catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Avatar upload failed: ${e.message}')),
              );
            }
          }
        }

        if (context.mounted) context.go('/home');
      } on AuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } on PostgrestException catch (e) {
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              GestureDetector(
                onTap: pickAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (avatarBytes.value != null)
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: MemoryImage(avatarBytes.value!),
                      )
                    else
                      AvatarWidget(
                        name: username.text.isEmpty ? 'You' : username.text,
                        radius: 48,
                        borderColor: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to add profile photo',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 28),
              InputField(
                controller: username,
                label: 'Username',
                prefix: const Icon(Icons.alternate_email_rounded, size: 22),
              ),
              const SizedBox(height: 16),
              InputField(
                controller: email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                prefix: const Icon(Icons.mail_outline_rounded, size: 22),
              ),
              const SizedBox(height: 16),
              InputField(
                controller: password,
                label: 'Password',
                obscure: true,
                prefix: const Icon(Icons.lock_outline_rounded, size: 22),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Sign up',
                isLoading: loading.value,
                onPressed: loading.value ? null : submit,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
