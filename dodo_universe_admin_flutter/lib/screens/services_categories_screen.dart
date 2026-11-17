import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class ServicesCategoriesScreen extends StatefulWidget {
  const ServicesCategoriesScreen({super.key});

  @override
  State<ServicesCategoriesScreen> createState() => _ServicesCategoriesScreenState();
}

class _ServicesCategoriesScreenState extends State<ServicesCategoriesScreen> {
  final _client = AdminApiClient();
  List<ServiceCategoryItem> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _client.getCategories();
      if (mounted) {
        setState(() {
          _categories = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showCategoryDialog({ServiceCategoryItem? existing, String? parentId, String? parentName}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final slugCtrl = TextEditingController(text: existing?.slug ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String categoryType = existing?.categoryType ?? 'container';
    bool allowListings = existing?.allowListings ?? false;
    bool isActive = existing?.isActive ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null
              ? (parentName != null ? 'Add Subcategory under "$parentName"' : 'Create Root Category')
              : 'Edit Category "${existing.name}"'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    onChanged: (val) {
                      if (existing == null) {
                        slugCtrl.text = val.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
                        setDialogState(() {});
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category / Service Name *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slugCtrl,
                    decoration: const InputDecoration(labelText: 'URL Slug *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: categoryType,
                    decoration: const InputDecoration(labelText: 'Classification Type'),
                    items: const [
                      DropdownMenuItem(value: 'container', child: Text('Container (Houses Subcategories)')),
                      DropdownMenuItem(value: 'bookable_service', child: Text('Bookable Service (Direct Ordering)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          categoryType = val;
                          if (categoryType == 'bookable_service') {
                            allowListings = true;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Allow Vendor Listings & Quotes', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Permits vendors to attach products or services to this node', style: TextStyle(fontSize: 11)),
                    value: allowListings,
                    onChanged: (val) => setDialogState(() => allowListings = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Active Status', style: TextStyle(fontSize: 13)),
                    value: isActive,
                    onChanged: (val) => setDialogState(() => isActive = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.pine700),
              child: const Text('Save Category', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty && slugCtrl.text.trim().isNotEmpty) {
      final payload = {
        'name': nameCtrl.text.trim(),
        'slug': slugCtrl.text.trim(),
        'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'category_type': categoryType,
        'allow_listings': allowListings,
        'is_active': isActive,
        'sort_order': existing?.sortOrder ?? 0,
        if (existing == null && parentId != null) 'parent_id': parentId,
      };

      try {
        if (existing == null) {
          await _client.createCategory(payload);
        } else {
          await _client.updateCategory(existing.id, payload);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "${nameCtrl.text.trim()}" saved.')),
          );
        }
        _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save category: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(ServiceCategoryItem cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${cat.name}"? If it has subcategories or active listings, deletion may fail.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.error),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _client.deleteCategory(cat.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "${cat.name}" deleted.')),
          );
        }
        _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete category: $e')),
          );
        }
      }
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
                    'Services & Categories',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Recursive unlimited hierarchy: Root categories, subcategories, and bookable services',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadCategories,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminTheme.pine700,
                      side: const BorderSide(color: AdminTheme.pine700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCategoryDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Root Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.pine700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tree Container
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTheme.border),
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator(color: AdminTheme.pine700)),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text(_error!, style: const TextStyle(color: AdminTheme.error))),
                      )
                    : _categories.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: EmptyStateView(
                              title: 'No categories created yet',
                              message: 'Create your first root category to start organizing platform services.',
                              icon: Icons.layers_clear_outlined,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AdminTheme.borderLight),
                            itemBuilder: (context, index) {
                              return _buildCategoryNode(_categories[index], 0);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryNode(ServiceCategoryItem item, int depth) {
    final hasChildren = item.children.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 24.0, right: 16, top: 10, bottom: 10),
          child: Row(
            children: [
              Icon(
                hasChildren
                    ? Icons.folder_outlined
                    : (item.categoryType == 'bookable_service' ? Icons.handyman_outlined : Icons.insert_drive_file_outlined),
                size: 20,
                color: item.categoryType == 'bookable_service' ? AdminTheme.pine700 : AdminTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        AdminBadge(
                          label: item.categoryType == 'bookable_service' ? 'Service' : 'Container',
                          status: item.categoryType == 'bookable_service' ? 'active' : 'info',
                        ),
                        if (item.allowListings) ...[
                          const SizedBox(width: 6),
                          const AdminBadge(label: 'Listings Allowed', status: 'success'),
                        ],
                        if (!item.isActive) ...[
                          const SizedBox(width: 6),
                          const AdminBadge(label: 'Inactive', status: 'error'),
                        ],
                      ],
                    ),
                    Text(
                      'Slug: /${item.slug} ${item.description != null ? '• ${item.description}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                tooltip: 'Add Child Subcategory/Service',
                color: AdminTheme.pine700,
                onPressed: () => _showCategoryDialog(parentId: item.id, parentName: item.name),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit Category',
                color: AdminTheme.textSecondary,
                onPressed: () => _showCategoryDialog(existing: item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Delete Category',
                color: AdminTheme.error,
                onPressed: () => _deleteCategory(item),
              ),
            ],
          ),
        ),
        if (hasChildren)
          ...item.children.map((child) => _buildCategoryNode(child, depth + 1)),
      ],
    );
  }
}
