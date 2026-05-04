import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/providers/service_providers.dart';
import '../../presentation/providers/social_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state_widget.dart';

class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(friendsListProvider);
    final theme = Theme.of(context);

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Friends'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (friends) {
          if (friends.isEmpty) {
            return const EmptyStateWidget(
              title: 'No friends yet',
              subtitle: 'Search users and send a friend request.',
              icon: Icons.people_outline,
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(friendsListProvider);
              await ref.read(friendsListProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: friends.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final e = friends[i];
                final p = e.friendProfile;
                return Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        AvatarWidget(
                          name: p.username,
                          imageUrl: p.avatarUrl,
                          radius: 26,
                          showOnlineDot: true,
                          isOnline: false,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.username, style: theme.textTheme.titleMedium),
                              Text(
                                'Friend',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.offline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CustomButton(
                          label: 'Chat',
                          expand: false,
                          variant: CustomButtonVariant.outline,
                          onPressed: () async {
                            final chat = ref.read(chatServiceProvider);
                            try {
                              final room = await chat.getOrCreateDirectRoom(
                                otherUserId: e.friendId,
                              );
                              if (!context.mounted) return;
                              final uri = Uri(
                                path: '/chat/${room.id}',
                                queryParameters: {
                                  'name': p.username,
                                  'online': '0',
                                  if (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                                    'avatar': p.avatarUrl!,
                                },
                              );
                              context.push(uri.toString());
                            } on PostgrestException catch (err) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err.message)),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
