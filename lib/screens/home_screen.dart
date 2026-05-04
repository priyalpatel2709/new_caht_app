import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group.dart';
import '../models/room.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import '../services/group_service.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'friends_screen.dart';
import 'group_chat_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'search_users_screen.dart';

/// Bottom nav: Chats, Groups, Friends, Profile — plus notification bell (friend requests).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['Chats', 'Groups', 'Friends', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          StreamBuilder<int>(
            stream: context.read<FriendService>().watchIncomingPendingCount(),
            builder: (context, snapshot) {
              final n = snapshot.data ?? 0;
              return Badge(
                isLabelVisible: n > 0,
                label: Text('$n'),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          if (_index == 2)
            IconButton(
              icon: const Icon(Icons.person_search),
              tooltip: 'Search users',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SearchUsersScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          _ChatsTab(),
          _GroupsTab(),
          FriendsScreen(embedded: true),
          ProfileScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ChatsTab extends StatefulWidget {
  const _ChatsTab();

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  late Future<List<Room>> _roomsFuture;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _loading = true;
      _roomsFuture = context.read<ChatService>().fetchAllRooms();
    });
    _roomsFuture.whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _showCreateRoomDialog() async {
    final room = await showDialog<Room>(
      context: context,
      builder: (context) => const _CreateRoomDialog(),
    );
    if (!mounted || room == null) return;
    _load();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(room: room, titleOverride: room.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Room>>(
          future: _roomsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || _loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final msg = snapshot.error is PostgrestException
                  ? (snapshot.error! as PostgrestException).message
                  : snapshot.error.toString();
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load rooms: $msg'),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              );
            }
            final rooms = snapshot.data ?? [];
            if (rooms.isEmpty) {
              return const Center(
                child: Text('No rooms yet.\nTap + to start a room.'),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (context, i) {
                  final room = rooms[i];
                  final isDm = room.name.startsWith('dm|');
                  final title = isDm ? 'Direct message' : room.name;
                  return ListTile(
                    leading: Icon(isDm ? Icons.lock_person_outlined : Icons.tag),
                    title: Text(title),
                    subtitle: Text(isDm ? 'Private chat' : room.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatScreen(room: room, titleOverride: title),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'fab_chats_new_room',
            onPressed: _showCreateRoomDialog,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _GroupsTab extends StatefulWidget {
  const _GroupsTab();

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  late Future<List<GroupMembership>> _future;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _loading = true;
      _future = context.read<GroupService>().fetchMyGroups();
    });
    _future.whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<GroupMembership>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || _loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('No groups yet'));
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return const Center(child: Text('No groups yet'));
            }
            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final m = list[i];
                  final g = m.group;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: g.avatarUrl != null && g.avatarUrl!.isNotEmpty
                          ? NetworkImage(g.avatarUrl!)
                          : null,
                      child: g.avatarUrl == null || g.avatarUrl!.isEmpty
                          ? const Icon(Icons.groups)
                          : null,
                    ),
                    title: Text(g.name),
                    subtitle: Text('You are ${m.role}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupChatScreen(group: g, myRole: m.role),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'fab_groups_new_group',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              );
              if (mounted) _load();
            },
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog();

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  late final TextEditingController _nameController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (name.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Please enter a room name.')),
      );
      return;
    }

    final chatService = context.read<ChatService>();

    setState(() => _submitting = true);
    var ok = false;
    try {
      final room = await chatService.createRoom(name: name);
      if (!mounted) return;
      ok = true;
      Navigator.of(context).pop(room);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    } finally {
      if (mounted && !ok) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New room'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Room name',
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (!_submitting) _submit();
        },
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
