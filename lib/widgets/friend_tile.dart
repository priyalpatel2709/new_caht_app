import 'package:flutter/material.dart';

import '../models/friend_request.dart';

class FriendTile extends StatelessWidget {
  final FriendEdge friend;
  final VoidCallback onTap;

  const FriendTile({
    super.key,
    required this.friend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = friend.friendProfile;
    final url = p.avatarUrl;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
        child: url == null || url.isEmpty
            ? Text(p.username.isNotEmpty ? p.username[0].toUpperCase() : '?')
            : null,
      ),
      title: Text(p.username),
      subtitle: const Text('Tap to chat'),
      trailing: const Icon(Icons.chat_bubble_outline),
    );
  }
}
