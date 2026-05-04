import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum CustomButtonVariant { filled, outline, ghost }

class CustomButton extends StatefulWidget {
  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CustomButtonVariant.filled,
    this.icon,
    this.expand = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool isLoading;

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = widget.onPressed == null || widget.isLoading;

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.variant == CustomButtonVariant.filled
                  ? Colors.white
                  : AppColors.primary,
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20),
            const SizedBox(width: 8),
          ],
          Text(widget.label),
        ],
      ],
    );

    final gradient = widget.variant == CustomButtonVariant.filled
        ? const LinearGradient(
            colors: [AppColors.primary, Color(0xFF6B77F5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : null;

    final button = switch (widget.variant) {
      CustomButtonVariant.filled => DecoratedBox(
          decoration: BoxDecoration(
            gradient: disabled ? null : gradient,
            color: disabled ? theme.colorScheme.surfaceContainerHighest : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : widget.onPressed,
              onHighlightChanged: (v) {
                if (disabled) return;
                if (v) {
                  _press.forward();
                } else {
                  _press.reverse();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: disabled
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                        : Colors.white,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      CustomButtonVariant.outline => OutlinedButton(
          onPressed: disabled ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: const BorderSide(color: AppColors.primary),
          ),
          child: child,
        ),
      CustomButtonVariant.ghost => TextButton(
          onPressed: disabled ? null : widget.onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: child,
        ),
    };

    return ScaleTransition(
      scale: _scale,
      child: widget.expand
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}
