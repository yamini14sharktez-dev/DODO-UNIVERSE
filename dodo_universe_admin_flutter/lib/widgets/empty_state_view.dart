import 'package:flutter/material.dart';
import '../core/theme.dart';

class EmptyStateView extends StatelessWidget {
  final String title;
  final String? message;
  final String? description;
  final IconData icon;
  final Widget? action;

  const EmptyStateView({
    super.key,
    this.title = 'No records found yet',
    this.message,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveText = message ?? description ?? 'There is currently no platform data available in this section.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AdminTheme.background,
                shape: BoxShape.circle,
                border: Border.all(color: AdminTheme.border),
              ),
              child: Icon(icon, color: AdminTheme.textMuted, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AdminTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                effectiveText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AdminTheme.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
