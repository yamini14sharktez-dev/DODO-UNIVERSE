import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/dashboard_models.dart';
import '../screens/provider_detail_sheet.dart';
import '../widgets/provider_card.dart';

/// Explore tab: Find services and filter verified professionals.
class ExploreTab extends StatefulWidget {
  final VoidCallback? onOpenNotifications;

  const ExploreTab({super.key, this.onOpenNotifications});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  double _minRating = 0.0;
  bool _verifiedOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Providers',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _minRating = 0.0;
                        _verifiedOnly = false;
                      });
                      setState(() {});
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Rating Filter
              Text(
                'Minimum Rating',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [0.0, 4.5, 4.8, 4.9].map((rating) {
                  final isSelected = _minRating == rating;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        rating == 0.0 ? 'Any' : '$rating+ ★',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isSelected
                              ? AppTheme.surfaceWhite
                              : AppTheme.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.pineGreen,
                      backgroundColor: AppTheme.surfaceMuted,
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
                        setModalState(() => _minRating = rating);
                        setState(() {});
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Verified Pro switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppTheme.pineGreen,
                title: Text(
                  'Verified Professionals Only',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Only show providers with verified identity and vetted track records',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                value: _verifiedOnly,
                onChanged: (val) {
                  setModalState(() => _verifiedOnly = val);
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProviders = ServiceProvider.sampleProviders.where((p) {
      if (_selectedCategory != 'All' && p.category != _selectedCategory) {
        return false;
      }
      if (_verifiedOnly && !p.isVerified) {
        return false;
      }
      if (p.rating < _minRating) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesBio = p.bio.toLowerCase().contains(query);
        final matchesHeadline = p.headline.toLowerCase().contains(query);
        final matchesService =
            p.servicesOffered.any((s) => s.toLowerCase().contains(query));
        return matchesName || matchesBio || matchesHeadline || matchesService;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.canvasColor,
      appBar: AppBar(
        title: const Text('Find Services'),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  color: AppTheme.forestSlate, size: 20),
            ),
            onPressed: widget.onOpenNotifications,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: AppTheme.borderSubtle),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search skills, pros, or services...',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppTheme.textMuted, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _showFilterModal,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: (_verifiedOnly || _minRating > 0)
                          ? AppTheme.pineGreenLight
                          : AppTheme.surfaceWhite,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(
                        color: (_verifiedOnly || _minRating > 0)
                            ? AppTheme.pineGreen
                            : AppTheme.borderSubtle,
                      ),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: (_verifiedOnly || _minRating > 0)
                          ? AppTheme.pineGreen
                          : AppTheme.forestSlate,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Category Pills
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: ServiceCategory.sampleCategories.length + 1,
              itemBuilder: (context, index) {
                final categoryName = index == 0
                    ? 'All'
                    : ServiceCategory.sampleCategories[index - 1].name;
                final isSelected = _selectedCategory == categoryName;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 4, bottom: 4),
                  child: ChoiceChip(
                    label: Text(
                      categoryName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
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
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.pineGreen
                            : AppTheme.borderSubtle,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = categoryName);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Provider Results List
          Expanded(
            child: filteredProviders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 54, color: AppTheme.textSubtle),
                        const SizedBox(height: 12),
                        Text(
                          'No services available yet.',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try clearing search filters or check back later.',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    itemCount: filteredProviders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final p = filteredProviders[index];
                      return ProviderCard(
                        provider: p,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                ProviderDetailSheet(provider: p),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
