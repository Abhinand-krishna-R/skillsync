import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/ui_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'analyze_screen.dart';
import 'roadmap_screen.dart';
import 'profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  bool _wasLoading = false;
  AppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Wire up AppState listener for roadmap notifications.
    // Using addListener here (not build) ensures the snackbar fires exactly
    // once when loading transitions from true → false.
    final appState = context.read<AppState>();
    if (_appState != appState) {
      _appState?.removeListener(_onAppStateChanged);
      _appState = appState;
      _appState!.addListener(_onAppStateChanged);
    }

    final ui = context.read<UiState>();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: ui.isLightMode ? Brightness.dark : Brightness.light,
    ));
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  // Called by the AppState listener — never from build().
  void _onAppStateChanged() {
    if (!mounted) return;
    _handleRoadmapNotifications(_appState!.loadingRoadmap, _appState!.roadmapError);
  }

  void _handleRoadmapNotifications(bool isLoading, String? error) {
    if (!isLoading && _wasLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Roadmap generation failed: $error', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.hot,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Roadmap generated successfully!', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              backgroundColor: AppColors.neon3,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: () {
                context.read<UiState>().setTab(AppTab.roadmap);
              }),
            ),
          );
        }
      });
    }
    _wasLoading = isLoading;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ui = context.watch<UiState>();

    final screens = [
      const HomeScreen(),
      const ExploreScreen(),
      const AnalyzeScreen(),
      const RoadmapScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: ui.currentTab.index,
          children: screens,
        ),
      ),
      bottomNavigationBar: _BottomNav(
        current: ui.currentTab.index,
        unread: state.unreadCount,
        onTap: (i) => context.read<UiState>().setTab(AppTab.values[i]),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current, unread;
  final ValueChanged<int> onTap;
  const _BottomNav(
      {required this.current, required this.unread, required this.onTap});

  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
    _NavItem(Icons.science_outlined, Icons.science_rounded, 'Analyze'),
    _NavItem(Icons.map_outlined, Icons.map_rounded, 'Roadmap'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: AppColors.s3)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: List.generate(5, (i) {
              final item = _items[i];
              final isOn = i == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    onTap(i);
                    HapticFeedback.lightImpact();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isOn
                                ? AppColors.neon.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isOn ? item.activeIcon : item.icon,
                            size: 22,
                            color: isOn
                                ? AppColors.neon
                                : AppColors.txt4.withValues(alpha: 0.6),
                          ),
                        ),
                        // Notification badge on Home tab
                        if (i == 0 && unread > 0)
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.hot,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.hot.withValues(alpha: 0.6),
                                      blurRadius: 8)
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '$unread',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 2),
                      isOn
                          ? ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (b) => AppColors.grad1
                                  .createShader(
                                      Rect.fromLTWH(0, 0, b.width, b.height)),
                              child: Text(item.label,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.06)),
                            )
                          : Text(item.label,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.txt4.withValues(alpha: 0.6),
                                  letterSpacing: 0.06)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      );
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
