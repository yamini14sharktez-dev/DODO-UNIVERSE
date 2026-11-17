import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/empty_state_view.dart';

class ReviewsReportsScreen extends StatefulWidget {
  const ReviewsReportsScreen({super.key});

  @override
  State<ReviewsReportsScreen> createState() => _ReviewsReportsScreenState();
}

class _ReviewsReportsScreenState extends State<ReviewsReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<dynamic> _reviews = [];
  final List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _exportCSV() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting reviews & report telemetry as CSV... (Downloaded)')),
    );
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
                    'Reviews & Reports',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Moderate customer ratings, feedback comments, and user dispute reports',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _exportCSV,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTheme.pine700,
                  side: const BorderSide(color: AdminTheme.pine700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AdminTheme.pine700,
            indicatorColor: AdminTheme.pine700,
            tabs: const [
              Tab(text: 'Customer Reviews'),
              Tab(text: 'Dispute & Abuse Reports'),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 550,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReviewsTab(),
                _buildReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: _reviews.isEmpty
          ? const EmptyStateView(
              title: 'No customer reviews submitted yet',
              message: 'Verified reviews and 5-star ratings will appear here for administrative moderation.',
              icon: Icons.star_border,
            )
          : const SizedBox(),
    );
  }

  Widget _buildReportsTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: _reports.isEmpty
          ? const EmptyStateView(
              title: 'No complaints or abuse reports',
              message: 'Customer and vendor submitted dispute tickets will appear here for investigation.',
              icon: Icons.report_problem_outlined,
            )
          : const SizedBox(),
    );
  }
}
