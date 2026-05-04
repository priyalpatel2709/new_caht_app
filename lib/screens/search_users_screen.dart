import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../services/friend_service.dart';

/// Call 5–6: search by username, send friend request.
class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _controller = TextEditingController();
  List<Profile>? _results;
  bool _searching = false;

  final Set<String> _pendingTargets = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    // if (q.length < 2) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Type at least 2 characters.')),
    //   );
    //   return;
    // }

    setState(() {
      _searching = true;
      _results = null;
    });

    try {
      final list = await context.read<FriendService>().searchUsersByUsername(q);
      if (!mounted) return;
      setState(() => _results = list);
    } on PostgrestException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search failed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(Profile p) async {
    setState(() => _searching = true);
    try {
      await context.read<FriendService>().sendFriendRequest(p.id);
      if (!mounted) return;
      setState(() => _pendingTargets.add(p.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.code == '23505' ||
              e.message.toLowerCase().contains('duplicate') ||
              e.message.toLowerCase().contains('unique')
          ? 'Request already sent'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : _runSearch,
                  child: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _results == null && !_searching
                ? const Center(child: Text('Search for people by username'))
                : _searching && _results == null
                    ? const Center(child: CircularProgressIndicator())
                    : Builder(
                        builder: (context) {
                          final list = _results ?? [];
                          if (list.isEmpty) {
                            return const Center(child: Text('No users found'));
                          }
                          return ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final p = list[i];
                              final pending = _pendingTargets.contains(p.id);
                              final url = p.avatarUrl;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: url != null && url.isNotEmpty
                                      ? NetworkImage(url)
                                      : null,
                                  child: url == null || url.isEmpty
                                      ? Text(
                                          p.username.isNotEmpty
                                              ? p.username[0]
                                              : '?',
                                        )
                                      : null,
                                ),
                                title: Text(p.username),
                                trailing: pending
                                    ? const Chip(label: Text('Pending'))
                                    : FilledButton(
                                        onPressed:
                                            _searching ? null : () => _sendRequest(p),
                                        child: const Text('Add'),
                                      ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
