import 'package:flutter/material.dart';

import '../models/group.dart';

class GroupTile extends StatelessWidget {
  final Group group;
  final String? subtitle;
  final VoidCallback onTap;

  const GroupTile({
    super.key,
    required this.group,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = group.avatarUrl;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
        child: url == null || url.isEmpty
            ? const Icon(Icons.group_outlined)
            : null,
      ),
      title: Text(group.name),
      subtitle: subtitle != null
          ? Text(subtitle!)
          : (group.description != null && group.description!.isNotEmpty
              ? Text(
                  group.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
