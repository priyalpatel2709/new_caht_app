import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../../presentation/providers/service_providers.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/empty_state_widget.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Profile> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _q.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.removeListener(_onQueryChanged);
    _q.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _q.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await ref.read(friendServiceProvider).searchUsersByUsername(q);
      if (mounted) {
        setState(() {
          _results = list;
          _loading = false;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
          _results = [];
        });
      }
    }
  }

  Future<void> _sendRequest(Profile p) async {
    try {
      await ref.read(friendServiceProvider).sendFriendRequest(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request sent to ${p.username}')),
        );
      }
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _q,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by username',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
          ),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_q.text.trim().isEmpty) {
      return const EmptyStateWidget(
        title: 'Search',
        subtitle: 'Find people by username to add or message.',
        icon: Icons.manage_search_rounded,
      );
    }
    if (_results.isEmpty) {
      return const EmptyStateWidget(
        title: 'No matches',
        subtitle: 'Try a different spelling.',
        icon: Icons.search_off_rounded,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final p = _results[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          tileColor: theme.colorScheme.surface,
          leading: AvatarWidget(
            name: p.username,
            imageUrl: p.avatarUrl,
            radius: 24,
          ),
          title: Text(p.username),
          subtitle: const Text('Tap actions below'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _sendRequest(p),
                child: const Text('Add'),
              ),
              TextButton(
                onPressed: () async {
                  final router = GoRouter.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final chat = ref.read(chatServiceProvider);
                  try {
                    final room = await chat.getOrCreateDirectRoom(
                      otherUserId: p.id,
                    );
                    if (!mounted) return;
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
                  } on PostgrestException catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  }
                },
                child: const Text('Chat'),
              ),
            ],
          ),
        );
      },
    );
  }
}
