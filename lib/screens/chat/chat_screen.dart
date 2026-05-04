import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/message.dart';
import '../../presentation/providers/service_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/message_bubble.dart';

class ChatScreen extends HookConsumerWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.isOnline = false,
    this.avatarUrl,
  });

  final String chatId;
  final String title;
  final bool isOnline;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scroll = useScrollController();
    final text = useTextEditingController();
    final sending = useState(false);
    final chat = ref.watch(chatServiceProvider);
    final storage = ref.watch(storageServiceProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;

    Future<void> openFile(Message m) async {
      final messenger = ScaffoldMessenger.of(context);
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
        if (!context.mounted) return;
        if (url == null || url.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Cannot open file')),
          );
          return;
        }
        final uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Cannot open file')),
          );
        }
      } on StorageException catch (e) {
        if (!context.mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    Future<void> openImage(Message m) async {
      final url = m.fileUrl;
      if (url == null || url.isEmpty) return;
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open image')),
          );
        }
      }
    }

    Future<void> send() async {
      final t = text.text.trim();
      if (t.isEmpty || sending.value) return;
      sending.value = true;
      try {
        await chat.sendMessage(roomId: chatId, text: t);
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

    Future<void> pickAndSendImage() async {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
      );
      if (x == null || !context.mounted) return;
      final bytes = await x.readAsBytes();
      if (!context.mounted) return;
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      sending.value = true;
      try {
        final fileName = x.name.isNotEmpty ? x.name : 'upload.jpg';
        final path = await storage.uploadChatFile(
          currentUserId: uid,
          fileName: fileName,
          fileBytes: Uint8List.fromList(bytes),
          mimeType: 'image/jpeg',
        );
        final signed = await storage.createChatFileSignedUrl(path);
        await chat.sendFileMessage(
          roomId: chatId,
          fileName: fileName,
          signedUrl: signed,
          messageType: 'image',
          fileSizeInBytes: bytes.length,
          storagePath: path,
        );
      } on StorageException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
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

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarWidget(
              name: title,
              imageUrl: avatarUrl,
              radius: 20,
              heroTag: 'avatar-$chatId',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    isOnline ? 'Online' : 'Messages',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isOnline ? AppColors.online : AppColors.offline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: chat.streamMessagesForRoom(chatId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snap.error}'),
              ),
            );
          }
          final raw = snap.data ?? [];
          final messages = <Message>[];
          for (final row in raw) {
            try {
              messages.add(Message.fromJson(Map<String, dynamic>.from(row)));
            } catch (_) {
              // skip malformed rows
            }
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
                      child: MessageBubble(
                        message: m,
                        isMine: mine,
                        onOpenFile: () => openFile(m),
                        onOpenImage: () => openImage(m),
                      ),
                    );
                  },
                ),
              ),
              _MessageInputBar(
                controller: text,
                sending: sending.value,
                onSend: send,
                onEmoji: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Emoji picker — add a package when you need it',
                        style: Theme.of(ctx).textTheme.bodyLarge,
                      ),
                    ),
                  );
                },
                onAttach: pickAndSendImage,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageInputBar extends HookWidget {
  const _MessageInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onEmoji,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSend;
  final VoidCallback onEmoji;
  final Future<void> Function() onAttach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pressed = useState(false);

    return Material(
      elevation: 8,
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onEmoji,
                icon: const Icon(Icons.emoji_emotions_outlined),
              ),
              IconButton(
                onPressed: sending ? null : () => onAttach(),
                icon: const Icon(Icons.image_outlined),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTapDown: (_) => pressed.value = true,
                onTapUp: (_) => pressed.value = false,
                onTapCancel: () => pressed.value = false,
                onTap: sending
                    ? null
                    : () async {
                        await onSend();
                      },
                child: AnimatedScale(
                  scale: pressed.value ? 0.88 : 1,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: sending
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF6B77F5)],
                            ),
                      color: sending
                          ? theme.colorScheme.surfaceContainerHighest
                          : null,
                      shape: BoxShape.circle,
                      boxShadow: sending
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: sending
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
