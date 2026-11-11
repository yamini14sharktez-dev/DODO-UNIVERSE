import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Primary action button styled with DODO green and rounded corners.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final Widget? icon;
  final double? width;
  final double height;
  final Color? backgroundColor;
  final Color? textColor;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.width = double.infinity,
    this.height = 52.0,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = isEnabled && !isLoading && onPressed != null;

    final btnStyle = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppTheme.primaryGreen,
      foregroundColor: textColor ?? Colors.white,
      disabledBackgroundColor: AppTheme.borderSubtle,
      disabledForegroundColor: AppTheme.textMuted,
      elevation: 0,
      minimumSize: Size(width ?? double.infinity, height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
    );

    Widget content;
    if (isLoading) {
      content = const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ],
      );
    } else {
      content = Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: btnStyle,
        onPressed: effectiveEnabled ? onPressed : null,
        child: content,
      ),
    );
  }
}
