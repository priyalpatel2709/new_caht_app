import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.heroTag,
    this.showOnlineDot = false,
    this.isOnline = false,
    this.borderColor,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Object? heroTag;
  final bool showOnlineDot;
  final bool isOnline;
  final Color? borderColor;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color _bgFromName() {
    final hash = name.hashCode.abs();
    final hues = [220.0, 260.0, 190.0, 330.0, 160.0];
    final h = hues[hash % hues.length];
    return HSLColor.fromAHSL(1, h, 0.45, 0.52).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: _bgFromName(),
      backgroundImage:
          imageUrl != null && imageUrl!.isNotEmpty ? NetworkImage(imageUrl!) : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.42,
              ),
            )
          : null,
    );

    Widget wrapped = avatar;
    if (borderColor != null) {
      wrapped = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: 2),
        ),
        child: avatar,
      );
    }

    if (showOnlineDot) {
      wrapped = Stack(
        clipBehavior: Clip.none,
        children: [
          wrapped,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.42,
              height: radius * 0.42,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.online : AppColors.offline,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (heroTag != null) {
      wrapped = Hero(tag: heroTag!, child: wrapped);
    }

    return SizedBox(
      width: showOnlineDot ? size + 2 : size,
      height: showOnlineDot ? size + 2 : size,
      child: wrapped,
    );
  }
}

/// Stacked avatars for group header (overlapping circles).
class AvatarStackWidget extends StatelessWidget {
  const AvatarStackWidget({
    super.key,
    required this.names,
    this.imageUrls,
    this.size = 28,
    this.maxVisible = 3,
  });

  final List<String> names;
  final List<String?>? imageUrls;
  final double size;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final n = names.length.clamp(0, maxVisible);
    if (n == 0) return const SizedBox.shrink();
    final overlap = size * 0.35;
    final totalWidth = size + (n - 1) * (size - overlap);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: i * (size - overlap),
              child: AvatarWidget(
                name: names[i],
                imageUrl: imageUrls != null && i < imageUrls!.length
                    ? imageUrls![i]
                    : null,
                radius: size / 2,
              ),
            ),
        ],
      ),
    );
  }
}
