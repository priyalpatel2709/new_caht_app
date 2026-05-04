import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend_request.dart';
import '../services/friend_service.dart';
import '../widgets/request_tile.dart';

/// Incoming friend requests (call 7–9) + realtime stream (call 11).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _busy = false;

  Future<void> _accept(String id) async {
    setState(() => _busy = true);
    try {
      await context.read<FriendService>().acceptFriendRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Now friends!')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(String id) async {
    setState(() => _busy = true);
    try {
      await context.read<FriendService>().rejectFriendRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<FriendRequest>>(
        stream: context.read<FriendService>().streamIncomingPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No pending requests'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return const Center(child: Text('No pending requests'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return RequestTile(
                request: r,
                onAccept: _busy ? () {} : () => _accept(r.id),
                onReject: _busy ? () {} : () => _reject(r.id),
              );
            },
          );
        },
      ),
    );
  }
}
