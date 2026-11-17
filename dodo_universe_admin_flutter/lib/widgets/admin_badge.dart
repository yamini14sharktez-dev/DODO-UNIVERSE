import 'package:flutter/material.dart';

class AdminBadge extends StatelessWidget {
  final String? label;
  final String status;
  final Color? color;
  final Color? backgroundColor;

  const AdminBadge({
    super.key,
    this.label,
    required this.status,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    final s = status.toLowerCase();
    if (['approved', 'active', 'completed', 'successful', 'published', 'open', 'success'].contains(s)) {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF047857);
    } else if (['pending', 'under_review', 'info_requested', 'under_investigation', 'warning'].contains(s)) {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
    } else if (['rejected', 'cancelled', 'disputed', 'failed', 'suspended', 'hidden', 'flagged', 'error', 'inactive'].contains(s)) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFB91C1C);
    } else if (['super_admin', 'operations_admin', 'finance_admin', 'in_progress', 'draft', 'info'].contains(s)) {
      bg = const Color(0xFFF0F9FF);
      fg = const Color(0xFF0369A1);
    }

    final displayText = label ?? status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (color ?? fg).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color ?? fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color ?? fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
