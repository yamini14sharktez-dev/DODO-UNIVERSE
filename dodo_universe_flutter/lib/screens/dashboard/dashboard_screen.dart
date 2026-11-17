import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'screens/notifications_screen.dart';
import 'tabs/activity_tab.dart';
import 'tabs/explore_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/provider_tab.dart';

/// Responsive DODO Universe Marketplace Dashboard:
/// Adapts seamlessly between Mobile (Bottom Bar), Tablet (Nav Rail), and Desktop (Sidebar).
class DashboardScreen extends StatefulWidget {
  final IAuthService? authService;
  final int initialTabIndex;

  const DashboardScreen({
    super.key,
    this.authService,
    this.initialTabIndex = 0,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _currentIndex;
  late final IAuthService _auth;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _auth = widget.authService ?? AuthService.instance;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final fullName =
        (user?.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
            ? (user!.userMetadata!['full_name'] as String).split(' ').first
            : (user?.email?.split('@').first ?? 'User');

    final tabs = [
      HomeTab(
        userName: fullName,
        onNavigateTab: _onTabSelected,
        onOpenNotifications: _openNotifications,
      ),
      ExploreTab(
        onOpenNotifications: _openNotifications,
      ),
      ActivityTab(
        onOpenNotifications: _openNotifications,
      ),
      ProviderTab(
        onOpenNotifications: _openNotifications,
      ),
      ProfileTab(
        authService: _auth,
        onOpenNotifications: _openNotifications,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024) {
          return _buildDesktopLayout(tabs);
        } else if (constraints.maxWidth >= 640) {
          return _buildTabletLayout(tabs);
        } else {
          return _buildMobileLayout(tabs);
        }
      },
    );
  }

  // ----------------------------------------------------
  // MOBILE LAYOUT (< 640px): Standard Bottom Nav
  // ----------------------------------------------------
  Widget _buildMobileLayout(List<Widget> tabs) {
    return Scaffold(
      backgroundColor: AppTheme.canvasColor,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.surfaceWhite,
          selectedItemColor: AppTheme.pineGreen,
          unselectedItemColor: AppTheme.textMuted,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment_rounded),
              label: 'My Activity',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront_rounded),
              label: 'Provider Hub',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // TABLET LAYOUT (640px - 1023px): Navigation Rail
  // ----------------------------------------------------
  Widget _buildTabletLayout(List<Widget> tabs) {
    return Scaffold(
      backgroundColor: AppTheme.canvasColor,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            backgroundColor: AppTheme.surfaceWhite,
            indicatorColor: AppTheme.pineGreenLight,
            selectedIconTheme: const IconThemeData(color: AppTheme.pineGreen),
            unselectedIconTheme: const IconThemeData(color: AppTheme.textMuted),
            selectedLabelTextStyle: GoogleFonts.plusJakartaSans(
              color: AppTheme.pineGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelTextStyle: GoogleFonts.plusJakartaSans(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.pineGreen,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Center(
                  child: Text(
                    'D',
                    style: TextStyle(
                      color: AppTheme.surfaceWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: Text('Explore'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment_rounded),
                label: Text('Activity'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: Text('Provider'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text('Profile'),
              ),
            ],
          ),
          const VerticalDivider(
              width: 1, thickness: 1, color: AppTheme.borderSubtle),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // DESKTOP LAYOUT (>= 1024px): Permanent Fixed Sidebar
  // ----------------------------------------------------
  Widget _buildDesktopLayout(List<Widget> tabs) {
    return Scaffold(
      backgroundColor: AppTheme.canvasColor,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceWhite,
              border: Border(
                right: BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.pineGreen,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: const Center(
                          child: Text(
                            'D',
                            style: TextStyle(
                              color: AppTheme.surfaceWhite,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DODO Universe',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Service Marketplace',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Navigation Items
                _buildSidebarItem(
                    0, 'Home', Icons.home_outlined, Icons.home_rounded),
                _buildSidebarItem(1, 'Find Services', Icons.explore_outlined,
                    Icons.explore_rounded),
                _buildSidebarItem(2, 'My Activity', Icons.assignment_outlined,
                    Icons.assignment_rounded),
                _buildSidebarItem(3, 'Provider Hub', Icons.storefront_outlined,
                    Icons.storefront_rounded),
                _buildSidebarItem(4, 'Profile & Settings',
                    Icons.person_outline_rounded, Icons.person_rounded),

                const Spacer(),

                // Notifications action
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    leading: const Icon(Icons.notifications_none_rounded,
                        color: AppTheme.forestSlate),
                    title: Text(
                      'Notifications',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    onTap: _openNotifications,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Main Viewport
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: IndexedStack(
                  index: _currentIndex,
                  children: tabs,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
      int index, String label, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabSelected(index),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.pineGreenLight : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color:
                      isSelected ? AppTheme.pineGreen : AppTheme.textSecondary,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isSelected ? AppTheme.pineGreen : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
