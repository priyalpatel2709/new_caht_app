import 'package:flutter/material.dart';

/// Inline image preview for signed `file_url` (or any https URL).
class ImageMessageWidget extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const ImageMessageWidget({
    super.key,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 120,
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 48),
        ),
      ),
    );

    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}
