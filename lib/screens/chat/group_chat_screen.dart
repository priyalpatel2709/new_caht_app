import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:super_base_app/utils/file_helper.dart';

import '../../models/group_message.dart';
import '../../presentation/providers/service_providers.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/message_bubble.dart';

class GroupChatScreen extends HookConsumerWidget {
  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.title,
  });

  final String groupId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scroll = useScrollController();
    final text = useTextEditingController();
    final sending = useState(false);
    final group = ref.watch(groupServiceProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;

    Future<String?> resolveGroupFileUrl(GroupMessage m) async {
      try {
        String? url = m.fileUrl;

        if (m.filePath != null && m.filePath!.isNotEmpty) {
          try {
            url = await ref
                .read(storageServiceProvider)
                .createChatFileSignedUrlForOpen(m.filePath!);
          } on StorageException {
            url = m.fileUrl;
          }
        }

        if (url == null || url.isEmpty) return null;
        return url;
      } on StorageException {
        return null;
      }
    }

    Future<void> openGroupFile(GroupMessage m) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final url = await resolveGroupFileUrl(m);
        if (!context.mounted) return;
        if (url == null || url.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Cannot open file')),
          );
          return;
        }
        await FileHelper.openFile(url);
      } catch (e) {
        debugPrint(e.toString());
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to open file')),
        );
      }
    }

    final membersFuture = useMemoized(
      () => group.fetchGroupMembers(groupId),
      [groupId],
    );
    final membersSnap = useFuture(membersFuture);

    final memberRows = membersSnap.data ?? const <Map<String, dynamic>>[];
    final stackNames = <String>[];
    final stackUrls = <String?>[];
    for (final row in memberRows.take(4)) {
      final p = row['profiles'];
      Map<String, dynamic>? pmap;
      if (p is Map<String, dynamic>) {
        pmap = p;
      } else if (p is List && p.isNotEmpty) {
        pmap = Map<String, dynamic>.from(p.first as Map);
      }
      if (pmap != null) {
        stackNames.add((pmap['username'] ?? '?') as String);
        stackUrls.add(pmap['avatar_url'] as String?);
      }
    }
    if (stackNames.isEmpty) {
      stackNames.addAll(['Member', 'Member']);
    }

    Future<void> send() async {
      final t = text.text.trim();
      if (t.isEmpty || sending.value) return;
      sending.value = true;
      try {
        await group.sendGroupTextMessage(groupId: groupId, text: t);
        text.clear();
      } on PostgrestException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } finally {
        sending.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Hero(
              tag: 'group-$groupId',
              child: AvatarStackWidget(
                names: stackNames,
                imageUrls: stackUrls,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${memberRows.length} members',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: group.streamGroupMessages(groupId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          final raw = snap.data ?? [];
          final messages = <GroupMessage>[];
          for (final row in raw) {
            try {
              messages.add(
                GroupMessage.fromJson(Map<String, dynamic>.from(row)),
              );
            } catch (_) {}
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!scroll.hasClients || messages.isEmpty) return;
            scroll.jumpTo(scroll.position.maxScrollExtent);
          });

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = m.isFromCurrentUser(myId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GroupMessageBubble(
                        message: m,
                        isMine: mine,
                        onOpenFile: () => openGroupFile(m),
                        resolveFileUrl: () => resolveGroupFileUrl(m),
                      ),
                    );
                  },
                ),
              ),
              _GroupInputBar(
                controller: text,
                sending: sending.value,
                onSend: send,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupInputBar extends HookWidget {
  const _GroupInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Message the group…',
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              IconButton(
                onPressed: sending
                    ? null
                    : () async {
                        await onSend();
                      },
                icon: sending
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.send_rounded, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
