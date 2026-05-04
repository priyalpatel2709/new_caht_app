import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'avatar_widget.dart';

class ChatListItemData {
  const ChatListItemData({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timeLabel,
    this.avatarUrl,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isGroup = false,
  });

  final String id;
  final String name;
  final String lastMessage;
  final String timeLabel;
  final String? avatarUrl;
  final int unreadCount;
  final bool isOnline;
  final bool isGroup;
}

class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.data,
    required this.onTap,
    this.heroTag,
    this.onDelete,
    this.onMute,
  });

  final ChatListItemData data;
  final VoidCallback onTap;
  final Object? heroTag;
  final VoidCallback? onDelete;
  final VoidCallback? onMute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailing = data.unreadCount > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data.unreadCount > 99 ? '99+' : '${data.unreadCount}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : Text(
            data.timeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          );

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              AvatarWidget(
                name: data.name,
                imageUrl: data.avatarUrl,
                radius: 26,
                heroTag: heroTag,
                showOnlineDot: !data.isGroup,
                isOnline: data.isOnline,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        trailing,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: data.unreadCount > 0
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontWeight:
                            data.unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onDelete == null && onMute == null) return tile;

    return Slidable(
      key: ValueKey(data.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.38,
        children: [
          SlidableAction(
            onPressed: (_) => onMute?.call(),
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
            icon: Icons.notifications_off_outlined,
            label: 'Mute',
          ),
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: tile,
    );
  }
}
