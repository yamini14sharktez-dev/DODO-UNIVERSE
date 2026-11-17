import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/empty_state_view.dart';

class FormBuilderScreen extends StatefulWidget {
  const FormBuilderScreen({super.key});

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen> {
  final _client = AdminApiClient();
  List<ServiceCategoryItem> _flatCategories = [];
  String? _selectedCategoryId;
  List<FormFieldItem> _fields = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  static const _availableTypes = [
    {'type': 'text', 'label': 'Short Text', 'icon': Icons.short_text},
    {'type': 'textarea', 'label': 'Long Text Area', 'icon': Icons.notes},
    {'type': 'number', 'label': 'Numeric Input', 'icon': Icons.pin},
    {'type': 'dropdown', 'label': 'Dropdown Select', 'icon': Icons.arrow_drop_down_circle_outlined},
    {'type': 'radio', 'label': 'Single Choice (Radio)', 'icon': Icons.radio_button_checked},
    {'type': 'checkbox', 'label': 'Multiple Checkbox', 'icon': Icons.check_box_outlined},
    {'type': 'date', 'label': 'Date Picker', 'icon': Icons.calendar_today_outlined},
    {'type': 'time_slot', 'label': 'Time Slot', 'icon': Icons.access_time_outlined},
    {'type': 'file_upload', 'label': 'File / Document Upload', 'icon': Icons.upload_file_outlined},
  ];

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
      final roots = await _client.getCategories();
      final flat = <ServiceCategoryItem>[];
      void flatten(List<ServiceCategoryItem> list) {
        for (final c in list) {
          flat.add(c);
          if (c.children.isNotEmpty) flatten(c.children);
        }
      }
      flatten(roots);

      if (mounted) {
        setState(() {
          _flatCategories = flat;
          _isLoading = false;
          if (_flatCategories.isNotEmpty) {
            _selectedCategoryId = _flatCategories.first.id;
            _loadFormForCategory(_selectedCategoryId!);
          }
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

  Future<void> _loadFormForCategory(String categoryId) async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.getFormDefinition(categoryId);
      final schema = (res['schema'] as Map<String, dynamic>?)?['fields'] as List<dynamic>? ?? [];
      final loadedFields = schema.map((f) => FormFieldItem.fromJson(f as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _fields = loadedFields;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _fields = [];
          _isLoading = false;
        });
      }
    }
  }

  void _addField(String type) {
    setState(() {
      final count = _fields.length + 1;
      _fields.add(FormFieldItem(
        id: 'field_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        label: 'Field $count',
        placeholder: 'Enter $type...',
        required: false,
        options: (type == 'dropdown' || type == 'radio') ? ['Option 1', 'Option 2'] : null,
      ));
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
    });
  }

  void _moveField(int from, int to) {
    if (to < 0 || to >= _fields.length) return;
    setState(() {
      final item = _fields.removeAt(from);
      _fields.insert(to, item);
    });
  }

  Future<void> _saveForm() async {
    if (_selectedCategoryId == null) return;

    setState(() => _isSaving = true);
    try {
      final payload = {
        'schema': {
          'fields': _fields.map((f) => f.toJson()).toList(),
        },
      };

      await _client.saveFormDefinition(_selectedCategoryId!, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form definition published and versioned successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish form: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                    'Dynamic Form Builder',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Build category-specific quotation and booking forms with 9 input types',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveForm,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.publish, size: 16),
                label: Text(_isSaving ? 'Publishing...' : 'Publish Form Version'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.pine700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category Selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.category_outlined, color: AdminTheme.pine700),
                const SizedBox(width: 12),
                const Text('Select Category: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 12),
                Expanded(
                  child: _flatCategories.isEmpty
                      ? const Text('No categories available to attach forms to.')
                      : DropdownButton<String>(
                          value: _selectedCategoryId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _flatCategories.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.name} (${c.categoryType})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategoryId = val);
                              _loadFormForCategory(val);
                            }
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Layout: Palette on left/top, Canvas on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field Palette
              Container(
                width: 260,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Field Palette (9 Types)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    ..._availableTypes.map((t) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: OutlinedButton.icon(
                          onPressed: () => _addField(t['type'] as String),
                          icon: Icon(t['icon'] as IconData, size: 16),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(t['label'] as String, style: const TextStyle(fontSize: 12)),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminTheme.textPrimary,
                            side: const BorderSide(color: AdminTheme.border),
                            minimumSize: const Size(double.infinity, 38),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Canvas / Field List
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Form Canvas (${_fields.length} fields)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            _selectedCategoryId != null ? 'Category ID: $_selectedCategoryId' : '',
                            style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AdminTheme.border),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator(color: AdminTheme.pine700)),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(child: Text(_error!, style: const TextStyle(color: AdminTheme.error))),
                        )
                      else if (_fields.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: EmptyStateView(
                            title: 'Form canvas is empty',
                            message: 'Click any field type on the palette to add form inputs.',
                            icon: Icons.dynamic_form_outlined,
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _fields.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final field = _fields[index];
                            return _buildFieldCard(field, index);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCard(FormFieldItem field, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminTheme.pine100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(field.type.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.pine800)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 16),
                tooltip: 'Move Up',
                onPressed: index > 0 ? () => _moveField(index, index - 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 16),
                tooltip: 'Move Down',
                onPressed: index < _fields.length - 1 ? () => _moveField(index, index + 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: AdminTheme.error),
                tooltip: 'Remove Field',
                onPressed: () => _removeField(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(text: field.label),
                  onChanged: (val) {
                    _fields[index] = FormFieldItem(
                      id: field.id,
                      type: field.type,
                      label: val,
                      placeholder: field.placeholder,
                      required: field.required,
                      options: field.options,
                    );
                  },
                  decoration: const InputDecoration(labelText: 'Field Label *', isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(text: field.placeholder ?? ''),
                  onChanged: (val) {
                    _fields[index] = FormFieldItem(
                      id: field.id,
                      type: field.type,
                      label: field.label,
                      placeholder: val,
                      required: field.required,
                      options: field.options,
                    );
                  },
                  decoration: const InputDecoration(labelText: 'Placeholder', isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Checkbox(
                    value: field.required,
                    onChanged: (val) {
                      setState(() {
                        _fields[index] = FormFieldItem(
                          id: field.id,
                          type: field.type,
                          label: field.label,
                          placeholder: field.placeholder,
                          required: val ?? false,
                          options: field.options,
                        );
                      });
                    },
                  ),
                  const Text('Required', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          if (field.type == 'dropdown' || field.type == 'radio' || field.type == 'checkbox') ...[
            const SizedBox(height: 8),
            Text('Options: ${(field.options ?? []).join(', ')}',
                style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
          ],
        ],
      ),
    );
  }
}
