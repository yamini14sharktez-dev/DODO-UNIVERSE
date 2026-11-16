import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/dashboard_models.dart';

/// Notifications screen organized into categories with mark-as-read functionality.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<AppNotification> _notifications;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _notifications = List.from(AppNotification.sampleNotifications);
  }

  void _markAllAsRead() {
    setState(() {
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                title: n.title,
                message: n.message,
                timestamp: n.timestamp,
                category: n.category,
                isRead: true,
              ))
          .toList();
    });
  }

  void _toggleNotificationRead(String id) {
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        final current = _notifications[idx];
        _notifications[idx] = AppNotification(
          id: current.id,
          title: current.title,
          message: current.message,
          timestamp: current.timestamp,
          category: current.category,
          isRead: !current.isRead,
        );
      }
    });
  }

  IconData _getCategoryIcon(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.orders:
        return Icons.shopping_bag_outlined;
      case NotificationCategory.requests:
        return Icons.request_quote_outlined;
      case NotificationCategory.provider:
        return Icons.storefront_outlined;
      case NotificationCategory.payments:
        return Icons.account_balance_wallet_outlined;
      case NotificationCategory.account:
        return Icons.person_outline_rounded;
    }
  }

  String _formatTimestamp(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_selectedCategory == 'All') return true;
      if (_selectedCategory == 'Orders') {
        return n.category == NotificationCategory.orders;
      }
      if (_selectedCategory == 'Requests') {
        return n.category == NotificationCategory.requests;
      }
      if (_selectedCategory == 'Provider') {
        return n.category == NotificationCategory.provider;
      }
      if (_selectedCategory == 'Payments') {
        return n.category == NotificationCategory.payments;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.canvasColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Mark All Read'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: ['All', 'Orders', 'Requests', 'Provider', 'Payments']
                  .map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.surfaceWhite
                            : AppTheme.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.pineGreen,
                    backgroundColor: AppTheme.surfaceWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusPill),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.pineGreen
                            : AppTheme.borderSubtle,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_none_rounded,
                            size: 48, color: AppTheme.textSubtle),
                        const SizedBox(height: 12),
                        Text(
                          "You're all caught up.",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No new notifications at this time.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: n.isRead
                              ? AppTheme.surfaceWhite
                              : AppTheme.surfaceSage.withValues(alpha: 0.35),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(
                            color: n.isRead
                                ? AppTheme.borderSubtle
                                : AppTheme.pineGreen.withValues(alpha: 0.3),
                          ),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: n.isRead
                                    ? AppTheme.surfaceMuted
                                    : AppTheme.pineGreenLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getCategoryIcon(n.category),
                                size: 18,
                                color: n.isRead
                                    ? AppTheme.forestSlate
                                    : AppTheme.pineGreen,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          n.title,
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        _formatTimestamp(n.timestamp),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.message,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: Icon(
                                n.isRead
                                    ? Icons.mark_email_unread_outlined
                                    : Icons.mark_email_read_outlined,
                                size: 18,
                                color: AppTheme.textMuted,
                              ),
                              tooltip: n.isRead ? 'Mark Unread' : 'Mark Read',
                              onPressed: () => _toggleNotificationRead(n.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
