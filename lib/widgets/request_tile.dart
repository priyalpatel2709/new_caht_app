import 'package:flutter/material.dart';

import '../models/friend_request.dart';

class RequestTile extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const RequestTile({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final p = request.senderProfile;
    final name = p?.username ?? 'Someone';
    final url = p?.avatarUrl;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  url != null && url.isNotEmpty ? NetworkImage(url) : null,
              child: url == null || url.isEmpty
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    'Wants to be friends',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onReject, child: const Text('Reject')),
            FilledButton(onPressed: onAccept, child: const Text('Accept')),
          ],
        ),
      ),
    );
  }
}
