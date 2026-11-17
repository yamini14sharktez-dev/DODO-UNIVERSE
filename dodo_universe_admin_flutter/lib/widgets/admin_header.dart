import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'admin_badge.dart';

class AdminHeader extends StatelessWidget {
  final String title;
  final AdminUser? admin;
  final VoidCallback onLogout;

  const AdminHeader({
    super.key,
    required this.title,
    this.admin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AdminTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const Text(
                'Live PostgreSQL records synchronized',
                style: TextStyle(
                  fontSize: 11,
                  color: AdminTheme.textSecondary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (admin != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AdminTheme.pine50,
                    shape: BoxShape.circle,
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: AdminTheme.pine700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin!.fullName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    Text(
                      admin!.email,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AdminTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                AdminBadge(status: admin!.role),
                const SizedBox(width: 16),
              ],
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, size: 14),
                label: const Text('Logout', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTheme.error,
                  side: const BorderSide(color: AdminTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
