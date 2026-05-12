import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Inline image preview for signed `file_url` (or any https URL).
class ImageMessageWidget extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const ImageMessageWidget({super.key, required this.imageUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,

          // Better cache behavior
          memCacheWidth: 600,
          memCacheHeight: 600,

          placeholder: (context, url) => const SizedBox(
            width: 120,
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),

          errorWidget: (context, url, error) => const SizedBox(
            width: 120,
            height: 120,
            child: Center(child: Icon(Icons.broken_image, size: 48)),
          ),

          fadeInDuration: const Duration(milliseconds: 150),
          fadeOutDuration: const Duration(milliseconds: 150),
        ),
      ),
    );

    if (onTap == null) return child;

    return InkWell(onTap: onTap, child: child);
  }
}
