import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum ChatBubbleAttachment { none, image }

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isMine,
    this.timeLabel,
    this.attachment = ChatBubbleAttachment.none,
    this.senderName,
    this.imagePreviewUrl,
  });

  final String text;
  final bool isMine;
  final String? timeLabel;
  final ChatBubbleAttachment attachment;
  final String? senderName;
  final String? imagePreviewUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = isMine
        ? (isDark ? AppColors.sentBubbleDark : AppColors.sentBubbleLight)
        : (isDark ? AppColors.receivedBubbleDark : AppColors.receivedBubbleLight);

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 18),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (senderName != null && senderName!.isNotEmpty && !isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      senderName!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                if (attachment == ChatBubbleAttachment.image &&
                    imagePreviewUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(
                        imagePreviewUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                if (attachment == ChatBubbleAttachment.image &&
                    imagePreviewUrl != null)
                  const SizedBox(height: 8),
                Text(
                  text,
                  style: AppTypography.bubbleText(context, isMine: isMine),
                ),
                if (timeLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeLabel!,
                    style: AppTypography.bubbleCaption(context, isMine: isMine),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
