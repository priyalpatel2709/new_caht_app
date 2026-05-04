import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/friend_request.dart';
import '../../models/outgoing_friend_request.dart';
import '../../presentation/providers/service_providers.dart';
import '../../presentation/providers/social_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/empty_state_widget.dart';

class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() =>
      _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _accept(FriendRequest r) async {
    try {
      await ref.read(friendServiceProvider).acceptFriendRequest(r.id);
      ref.invalidate(incomingFriendRequestsProvider);
      ref.invalidate(incomingFriendRequestCountProvider);
      ref.invalidate(friendsListProvider);
      ref.invalidate(outgoingFriendRequestsProvider);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _reject(FriendRequest r) async {
    try {
      await ref.read(friendServiceProvider).rejectFriendRequest(r.id);
      ref.invalidate(incomingFriendRequestsProvider);
      ref.invalidate(incomingFriendRequestCountProvider);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incoming = ref.watch(incomingFriendRequestsProvider);
    final outgoing = ref.watch(outgoingFriendRequestsProvider);

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Friend requests'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Incoming'),
            Tab(text: 'Outgoing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          incoming.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) => _IncomingList(
              items: list,
              theme: theme,
              onAccept: _accept,
              onReject: _reject,
            ),
          ),
          outgoing.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) => _OutgoingList(items: list, theme: theme),
          ),
        ],
      ),
    );
  }
}

class _IncomingList extends StatelessWidget {
  const _IncomingList({
    required this.items,
    required this.theme,
    required this.onAccept,
    required this.onReject,
  });

  final List<FriendRequest> items;
  final ThemeData theme;
  final void Function(FriendRequest) onAccept;
  final void Function(FriendRequest) onReject;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        title: 'No incoming requests',
        subtitle: 'When someone adds you, they show up here.',
        icon: Icons.mail_outline,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        final name = r.senderProfile?.username ?? 'Unknown';
        final avatar = r.senderProfile?.avatarUrl;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AvatarWidget(
                    name: name,
                    imageUrl: avatar,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onReject(r),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => onAccept(r),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OutgoingList extends StatelessWidget {
  const _OutgoingList({
    required this.items,
    required this.theme,
  });

  final List<OutgoingFriendRequest> items;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        title: 'No outgoing requests',
        subtitle: 'Invites you send appear here.',
        icon: Icons.send_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        final p = r.receiver;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AvatarWidget(
                    name: p.username,
                    imageUrl: p.avatarUrl,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      p.username,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    'Pending',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
