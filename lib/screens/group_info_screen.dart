import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group.dart';
import '../services/group_service.dart';

/// Calls 21, 26, 27: members list, admin remove, leave.
class GroupInfoScreen extends StatefulWidget {
  final Group group;
  final String myRole;

  const GroupInfoScreen({
    super.key,
    required this.group,
    required this.myRole,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context.read<GroupService>().fetchGroupMembers(widget.group.id);
    });
  }

  bool get _isAdmin => widget.myRole == 'admin';

  Future<void> _removeMember(String userId) async {
    setState(() => _busy = true);
    try {
      await context.read<GroupService>().removeMemberFromGroup(
            groupId: widget.group.id,
            targetUserId: userId,
          );
      if (!mounted) return;
      _reload();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.toLowerCase().contains('policy') ||
                    e.message.toLowerCase().contains('permission')
                ? 'Only admin can remove members'
                : e.message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    setState(() => _busy = true);
    try {
      await context.read<GroupService>().leaveGroup(widget.group.id);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ProfileSummary _parseProfile(Map<String, dynamic> row) {
    final raw = row['profiles'];
    Map<String, dynamic> m;
    if (raw is Map<String, dynamic>) {
      m = raw;
    } else if (raw is List && raw.isNotEmpty) {
      m = raw.first as Map<String, dynamic>;
    } else {
      m = {};
    }
    return ProfileSummary(
      id: m['id'] as String? ?? row['user_id'] as String,
      username: (m['username'] ?? 'Unknown') as String,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error is PostgrestException ? (snapshot.error! as PostgrestException).message : snapshot.error}',
              ),
            );
          }
          final members = snapshot.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.group.description != null &&
                  widget.group.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(widget.group.description!),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Members (${members.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, i) {
                    final row = members[i];
                    final role = (row['role'] ?? 'member') as String;
                    final p = _parseProfile(row);
                    final isSelf = p.id == me;
                    return ListTile(
                      leading: CircleAvatar(
                        child: role == 'admin'
                            ? const Icon(Icons.workspace_premium)
                            : Text(
                                p.username.isNotEmpty
                                    ? p.username[0].toUpperCase()
                                    : '?',
                              ),
                      ),
                      title: Text(p.username),
                      subtitle: Text(role),
                      trailing: _isAdmin && !isSelf && role != 'admin'
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _busy ? null : () => _removeMember(p.id),
                            )
                          : null,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _leave,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Leave group'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProfileSummary {
  final String id;
  final String username;

  ProfileSummary({required this.id, required this.username});
}
