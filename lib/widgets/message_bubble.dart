import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:linkify/linkify.dart' show PhoneNumberLinkifier;
import 'package:timeago/timeago.dart' as timeago;

import '../models/group_message.dart';
import '../models/message.dart';
import '../utils/message_interaction.dart';
import 'file_message_widget.dart';
import 'image_message_widget.dart';

/// DM bubble: text / image / file based on [Message.messageType].
///
/// Uses [Align] so each bubble pins left or right regardless of list/RTL parents.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenImage;
  final Future<String?> Function()? resolveFileUrl;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onOpenFile,
    this.onOpenImage,
    this.resolveFileUrl,
  });

  String get _copyPlain {
    if (message.isImage) {
      return (message.fileUrl?.isNotEmpty ?? false)
          ? message.fileUrl!
          : message.content;
    }
    if (message.isFile) {
      return message.fileName ?? message.content;
    }
    return message.content;
  }

  @override
  Widget build(BuildContext context) {
    return _MessageBubbleFrame(
      isMine: isMine,
      useGroupAccent: false,
      username: !isMine ? message.profile.username : null,
      createdAt: message.createdAt,
      copyPlainText: _copyPlain,
      content: _dmBody(context),
    );
  }

  Widget _dmBody(BuildContext context) {
    if (message.isImage && (message.fileUrl?.isNotEmpty ?? false)) {
      return ImageMessageWidget(
        imageUrl: message.fileUrl!,
        onTap: onOpenImage,
      );
    }
    if (message.isFile) {
      return FileMessageWidget(
        fileName: message.fileName ?? message.content,
        fileSizeBytes: message.fileSize,
        onOpen: onOpenFile,
        resolveFileUrl: resolveFileUrl,
      );
    }
    return _LinkifyMessageBody(text: message.content);
  }
}

/// Group chat bubble (same layout, [GroupMessage]).
class GroupMessageBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMine;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenImage;
  final Future<String?> Function()? resolveFileUrl;

  const GroupMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onOpenFile,
    this.onOpenImage,
    this.resolveFileUrl,
  });

  String get _copyPlain {
    if (message.isImage) {
      return (message.fileUrl?.isNotEmpty ?? false)
          ? message.fileUrl!
          : message.content;
    }
    if (message.messageType == 'file') {
      return message.fileName ?? message.content;
    }
    return message.content;
  }

  @override
  Widget build(BuildContext context) {
    return _MessageBubbleFrame(
      isMine: isMine,
      useGroupAccent: true,
      username: !isMine ? message.profile.username : null,
      createdAt: message.createdAt,
      copyPlainText: _copyPlain,
      content: _groupBody(context),
    );
  }

  Widget _groupBody(BuildContext context) {
    if (message.isImage && (message.fileUrl?.isNotEmpty ?? false)) {
      return ImageMessageWidget(
        imageUrl: message.fileUrl!,
        onTap: onOpenImage,
      );
    }
    if (message.messageType == 'file') {
      return FileMessageWidget(
        fileName: message.fileName ?? message.content,
        fileSizeBytes: message.fileSize,
        onOpen: onOpenFile,
        resolveFileUrl: resolveFileUrl,
      );
    }
    return _LinkifyMessageBody(text: message.content);
  }
}

/// Selectable text with tappable http(s), www, email, and phone patterns.
class _LinkifyMessageBody extends StatelessWidget {
  final String text;

  const _LinkifyMessageBody({required this.text});

  static const _linkifiers = [
    UrlLinkifier(),
    EmailLinkifier(),
    PhoneNumberLinkifier(),
  ];

  static const _linkifyOptions = LinkifyOptions(
    looseUrl: true,
    defaultToHttps: true,
    humanize: true,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium;
    return SelectableLinkify(
      text: text,
      linkifiers: _linkifiers,
      options: _linkifyOptions,
      style: base,
      onOpen: (link) => openLinkableElement(context, link),
      linkStyle: TextStyle(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: theme.colorScheme.primary,
      ),
      textAlign: TextAlign.start,
      enableInteractiveSelection: true,
    );
  }
}

class _MessageBubbleFrame extends StatelessWidget {
  final bool isMine;
  /// Group chats use [ColorScheme.tertiaryContainer] for “mine”; DMs use [primaryContainer].
  final bool useGroupAccent;
  final String? username;
  final DateTime createdAt;
  /// Plain string used for the copy action (full message body, file name, or image URL).
  final String copyPlainText;
  final Widget content;

  const _MessageBubbleFrame({
    required this.isMine,
    required this.useGroupAccent,
    required this.username,
    required this.createdAt,
    required this.copyPlainText,
    required this.content,
  });

  static const double _radius = 18;
  static const double _pin = 5;

  BorderRadius get _shape {
    if (isMine) {
      return const BorderRadius.only(
        topLeft: Radius.circular(_radius),
        topRight: Radius.circular(_radius),
        bottomLeft: Radius.circular(_radius),
        bottomRight: Radius.circular(_pin),
      );
    }
    return const BorderRadius.only(
      topLeft: Radius.circular(_radius),
      topRight: Radius.circular(_radius),
      bottomLeft: Radius.circular(_pin),
      bottomRight: Radius.circular(_radius),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxW = MediaQuery.sizeOf(context).width * 0.78;

    final Color bg;
    final Color onBg;
    if (isMine) {
      if (useGroupAccent) {
        bg = cs.tertiaryContainer;
        onBg = cs.onTertiaryContainer;
      } else {
        bg = cs.primaryContainer;
        onBg = cs.onPrimaryContainer;
      }
    } else {
      bg = cs.surfaceContainerHighest;
      onBg = cs.onSurfaceVariant;
    }

    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      color: onBg.withValues(alpha: 0.72),
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
    );
    final nameStyle = theme.textTheme.labelLarge?.copyWith(
      color: onBg,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
    );

    final canCopy = copyPlainText.trim().isNotEmpty;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: _shape,
          border: Border.all(
            color: theme.brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.brightness == Brightness.light ? 0.07 : 0.18),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: isMine ? onBg : theme.colorScheme.onSurface),
            child: IconTheme.merge(
              data: IconThemeData(color: isMine ? onBg : theme.colorScheme.onSurface, size: 22),
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (username != null && username!.isNotEmpty) ...[
                    Text(username!, style: nameStyle),
                    const SizedBox(height: 6),
                  ],
                  content,
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeago.format(createdAt),
                        style: timeStyle,
                      ),
                      if (canCopy) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          onPressed: () =>
                              copyMessageToClipboard(context, copyPlainText),
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: timeStyle?.color,
                          ),
                          tooltip: 'Copy message',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      ),
    );
  }
}
