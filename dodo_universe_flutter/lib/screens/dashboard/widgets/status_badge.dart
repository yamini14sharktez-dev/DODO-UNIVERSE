import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/dashboard_models.dart';

/// Tactile, organic status badge tailored for the Warm Nordic Atelier identity.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.fromOrderStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingConfirmation:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.warmOchreLight,
          textColor: AppTheme.warmOchre,
          icon: Icons.hourglass_top_rounded,
        );
      case OrderStatus.accepted:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.surfaceSage,
          textColor: AppTheme.pineGreen,
          icon: Icons.check_circle_outline_rounded,
        );
      case OrderStatus.inProgress:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.pineGreenLight,
          textColor: AppTheme.pineGreen,
          icon: Icons.sync_rounded,
        );
      case OrderStatus.completed:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.pineGreenLight,
          textColor: AppTheme.pineGreen,
          icon: Icons.task_alt_rounded,
        );
      case OrderStatus.cancelled:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.rustRedLight,
          textColor: AppTheme.rustRed,
          icon: Icons.cancel_outlined,
        );
    }
  }

  factory StatusBadge.fromRequestStatus(RequestStatus status) {
    switch (status) {
      case RequestStatus.submitted:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.surfaceMuted,
          textColor: AppTheme.textSecondary,
          icon: Icons.send_rounded,
        );
      case RequestStatus.providerResponded:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.surfaceSage,
          textColor: AppTheme.pineGreen,
          icon: Icons.forum_outlined,
        );
      case RequestStatus.quoteReceived:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.warmOchreLight,
          textColor: AppTheme.warmOchre,
          icon: Icons.local_offer_outlined,
        );
      case RequestStatus.accepted:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.pineGreenLight,
          textColor: AppTheme.pineGreen,
          icon: Icons.handshake_outlined,
        );
      case RequestStatus.completedOrClosed:
        return StatusBadge(
          label: status.label,
          backgroundColor: AppTheme.pineGreenLight,
          textColor: AppTheme.pineGreen,
          icon: Icons.check_circle_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: textColor.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
