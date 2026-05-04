import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend_request.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import '../widgets/friend_tile.dart';
import 'chat_screen.dart';
import 'search_users_screen.dart';

/// Friends list — tap friend to open DM. Use [embedded] inside [HomeScreen] (no extra scaffold).
class FriendsScreen extends StatefulWidget {
  final bool embedded;

  const FriendsScreen({super.key, this.embedded = false});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late Future<List<FriendEdge>> _future;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _loading = true;
      _future = context.read<FriendService>().fetchFriendsList();
    });
    _future.whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _openChat(FriendEdge friend) async {
    setState(() => _loading = true);
    try {
      final room = await context.read<ChatService>().getOrCreateDirectRoom(
            otherUserId: friend.friendId,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            room: room,
            titleOverride: friend.friendProfile.username,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<List<FriendEdge>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('No friends yet'));
        }
        final friends = snapshot.data ?? [];
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No friends yet'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SearchUsersScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_search),
                  label: const Text('Find people'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, i) {
              final f = friends[i];
              return FriendTile(friend: f, onTap: () => _openChat(f));
            },
          ),
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: body,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_friends_search',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
          );
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
