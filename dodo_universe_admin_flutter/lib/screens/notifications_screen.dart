import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetAudience = 'all';
  bool _isHighPriority = false;
  bool _isSending = false;

  final List<Map<String, dynamic>> _sentHistory = [];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide both announcement title and message.')),
      );
      return;
    }

    setState(() => _isSending = true);

    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _sentHistory.insert(0, {
        'id': 'notif_${DateTime.now().millisecondsSinceEpoch}',
        'title': title,
        'message': message,
        'target': _targetAudience,
        'priority': _isHighPriority ? 'high' : 'normal',
        'created_at': DateTime.now().toIso8601String(),
      });
      _titleController.clear();
      _messageController.clear();
      _isSending = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Broadcast announcement dispatched successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications & Announcements',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Broadcast operational alerts and push notifications to segmented platform users',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Composer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Compose Platform Announcement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Notification Title *', hintText: 'e.g. Scheduled Platform Maintenance'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message Body *',
                    hintText: 'Enter announcement details to be delivered to targeted devices...',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Target Audience: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _targetAudience,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Registered Users')),
                        DropdownMenuItem(value: 'customers', child: Text('Customers Only')),
                        DropdownMenuItem(value: 'vendors', child: Text('Active Vendors Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _targetAudience = val);
                      },
                    ),
                    const SizedBox(width: 24),
                    Checkbox(
                      value: _isHighPriority,
                      onChanged: (val) => setState(() => _isHighPriority = val ?? false),
                    ),
                    const Text('High Priority Alert', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendBroadcast,
                      icon: _isSending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 16),
                      label: Text(_isSending ? 'Sending...' : 'Dispatch Broadcast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.pine700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Broadcast History
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Broadcast Delivery History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Divider(height: 24, color: AdminTheme.border),
                if (_sentHistory.isEmpty)
                  const EmptyStateView(
                    title: 'No broadcast notifications sent yet',
                    message: 'Dispatched notifications will be tracked here for audit and analytics.',
                    icon: Icons.notifications_off_outlined,
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sentHistory.length,
                    separatorBuilder: (_, __) => const Divider(color: AdminTheme.borderLight),
                    itemBuilder: (context, index) {
                      final item = _sentHistory[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item['priority'] == 'high' ? AdminTheme.errorLight : AdminTheme.pine50,
                          child: Icon(
                            item['priority'] == 'high' ? Icons.priority_high : Icons.campaign_outlined,
                            color: item['priority'] == 'high' ? AdminTheme.error : AdminTheme.pine700,
                            size: 18,
                          ),
                        ),
                        title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(item['message'] as String, style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AdminBadge(label: (item['target'] as String).toUpperCase(), status: 'info'),
                            const SizedBox(width: 8),
                            Text(
                              (item['created_at'] as String).length >= 10
                                  ? (item['created_at'] as String).substring(0, 10)
                                  : item['created_at'] as String,
                              style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
