import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/providers/home_overview_provider.dart';
import '../../presentation/providers/service_providers.dart';
import '../../presentation/providers/social_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/chat_list_tile.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_shimmer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openChat(ChatListItemData c, {bool isGroup = false}) {
    final uri = Uri(
      path: isGroup ? '/group/${c.id}' : '/chat/${c.id}',
      queryParameters: {
        'name': c.name,
        if (!isGroup) 'online': c.isOnline ? '1' : '0',
        if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) 'avatar': c.avatarUrl!,
      },
    );
    context.push(uri.toString());
  }

  void _openPublicRoom(PublicRoomRow row) {
    final uri = Uri(
      path: '/chat/${row.room.id}',
      queryParameters: {
        'name': row.room.name,
        'online': '0',
      },
    );
    context.push(uri.toString());
  }

  Future<void> _fabSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: const Text('New chat'),
                  subtitle: const Text('Pick a friend'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPickFriendSheet();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.groups_2_outlined),
                  title: const Text('Create group'),
                  subtitle: const Text('Name and description'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _showCreateGroupDialog();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPickFriendSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Consumer(
              builder: (sheetCtx, ref, _) {
                final router = GoRouter.of(sheetCtx);
                final async = ref.watch(friendsListProvider);
                return async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (friends) {
                    if (friends.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Add friends from search first.'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: friends.length,
                      itemBuilder: (context, i) {
                        final e = friends[i];
                        final p = e.friendProfile;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: p.avatarUrl != null &&
                                    p.avatarUrl!.isNotEmpty
                                ? NetworkImage(p.avatarUrl!)
                                : null,
                            child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                                ? Text(
                                    p.username.isNotEmpty
                                        ? p.username[0].toUpperCase()
                                        : '?',
                                  )
                                : null,
                          ),
                          title: Text(p.username),
                          onTap: () async {
                            final chat = ref.read(chatServiceProvider);
                            try {
                              final room = await chat.getOrCreateDirectRoom(
                                otherUserId: e.friendId,
                              );
                              if (!sheetCtx.mounted) return;
                              Navigator.pop(sheetCtx);
                              final uri = Uri(
                                path: '/chat/${room.id}',
                                queryParameters: {
                                  'name': p.username,
                                  'online': '0',
                                  if (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                                    'avatar': p.avatarUrl!,
                                },
                              );
                              router.push(uri.toString());
                            } on PostgrestException catch (err) {
                              if (!sheetCtx.mounted) return;
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(content: Text(err.message)),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateGroupDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name')),
      );
      return;
    }
    try {
      final group = ref.read(groupServiceProvider);
      final g = await group.createGroup(
        groupName: name,
        description: descCtrl.text.trim(),
      );
      ref.invalidate(homeOverviewProvider);
      if (!mounted) return;
      final uri = Uri(
        path: '/group/${g.id}',
        queryParameters: {'name': g.name},
      );
      context.push(uri.toString());
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
    final overview = ref.watch(homeOverviewProvider);
    final profile = ref.watch(currentUserProfileProvider);
    final badge = ref.watch(incomingFriendRequestCountProvider);

    return AppScaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/profile'),
                child: profile.when(
                  loading: () => const CircleAvatar(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (err, stack) => AvatarWidget(
                    name: 'You',
                    radius: 20,
                    heroTag: 'profile-avatar',
                  ),
                  data: (p) => AvatarWidget(
                    name: p.username,
                    imageUrl: p.avatarUrl,
                    radius: 20,
                    heroTag: 'profile-avatar',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Messages', style: theme.textTheme.titleLarge),
                  Text(
                    'Chats · Groups · Rooms',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
          PopupMenuButton<String>(
            icon: Badge(
              isLabelVisible: (badge.valueOrNull ?? 0) > 0,
              label: Text('${badge.valueOrNull ?? 0}'),
              child: const Icon(Icons.more_vert_rounded),
            ),
            offset: const Offset(0, 8),
            onSelected: (v) {
              if (v == 'friends') context.push('/friends');
              if (v == 'requests') context.push('/friend-requests');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'friends', child: Text('Friends')),
              PopupMenuItem(value: 'requests', child: Text('Friend requests')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Groups'),
            Tab(text: 'Rooms'),
          ],
        ),
      ),
      fab: FloatingActionButton.extended(
        onPressed: _fabSheet,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New'),
      ),
      body: overview.when(
        loading: () => TabBarView(
          controller: _tabs,
          children: const [
            ChatListShimmer(),
            ChatListShimmer(),
            ChatListShimmer(),
          ],
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(homeOverviewProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => TabBarView(
          controller: _tabs,
          children: [
            _ChatListTab(
              items: data.dmChats,
              heroPrefix: 'avatar',
              onOpen: (c) => _openChat(c),
              onRefresh: () async {
                ref.invalidate(homeOverviewProvider);
                await ref.read(homeOverviewProvider.future);
              },
            ),
            _ChatListTab(
              items: data.groupChats,
              heroPrefix: 'group',
              onOpen: (c) => _openChat(c, isGroup: true),
              onRefresh: () async {
                ref.invalidate(homeOverviewProvider);
                await ref.read(homeOverviewProvider.future);
              },
            ),
            _PublicRoomsTab(
              rooms: data.publicRooms,
              onOpen: _openPublicRoom,
              onRefresh: () async {
                ref.invalidate(homeOverviewProvider);
                await ref.read(homeOverviewProvider.future);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatListTab extends StatelessWidget {
  const _ChatListTab({
    required this.items,
    required this.onOpen,
    required this.onRefresh,
    required this.heroPrefix,
  });

  final List<ChatListItemData> items;
  final void Function(ChatListItemData) onOpen;
  final Future<void> Function() onRefresh;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyStateWidget(
        title: 'Nothing here yet',
        subtitle: 'Use + to start a chat or create a group.',
        actionLabel: 'Refresh',
        onAction: () => onRefresh(),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final c = items[i];
          return ChatListTile(
            data: c,
            heroTag: '$heroPrefix-${c.id}',
            onTap: () => onOpen(c),
          );
        },
      ),
    );
  }
}

class _PublicRoomsTab extends StatelessWidget {
  const _PublicRoomsTab({
    required this.rooms,
    required this.onOpen,
    required this.onRefresh,
  });

  final List<PublicRoomRow> rooms;
  final void Function(PublicRoomRow) onOpen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rooms.isEmpty) {
      return EmptyStateWidget(
        title: 'No shared rooms',
        subtitle: 'Create a named room from your backend or seed data.',
        actionLabel: 'Refresh',
        onAction: () => onRefresh(),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: rooms.length,
        itemBuilder: (context, i) {
          final r = rooms[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onOpen(r),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AvatarWidget(
                        name: r.room.name,
                        radius: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.room.name, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              r.preview,
                              style: theme.textTheme.bodySmall,
                            ),
                            if (r.timeLabel != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                r.timeLabel!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => onOpen(r),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
