import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/ui_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(backgroundColor: AppColors.bg, body: SafeArea(child: Column(children: [
      SkillTopBar('Notifications', showBack: true, actions: [
        GestureDetector(
          onTap: () { context.read<AppState>().markAllRead(); showToast(context, 'All marked as read'); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), margin: const EdgeInsets.only(right: 8),
            child: Row(children: [
              Icon(Icons.check_rounded, size: 13, color: AppColors.neon3), const SizedBox(width: 4),
              Text('ALL READ', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neon3, letterSpacing: 0.05)),
            ]))),
      ]),
      Expanded(child: state.notifications.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.txt3), SizedBox(height: 16),
            Text('No notifications yet', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.txt)), const SizedBox(height: 8),
            Text('Complete modules and upload your resume\nto receive updates here', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.txt3)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: state.notifications.length,
            itemBuilder: (_, i) {
              final n = state.notifications[i];
              final color = Color(n.colorValue);
              return GestureDetector(
                onTap: () {
                  context.read<AppState>().markNotifRead(n.id);
                  // Route based on notification type
                  // Route to the relevant tab based on notification icon.
                  // 'target'/'map' → Roadmap (3), 'file_text' → Analyze (2),
                  // all others → Home (0). Always pop back after routing.
                  final tab = switch (n.icon) {
                    'target' || 'map'   => AppTab.roadmap,
                    'file_text'         => AppTab.analyze,
                    _                   => AppTab.home,
                  };
                  context.read<UiState>().setTab(tab);
                  Navigator.pop(context);
                },
                child: Container(padding: EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.s2))),
                  child: Row(children: [
                    Container(width: 38, height: 38,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), border: Border.all(color: color.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(10)),
                      child: Icon(n.iconData, color: color, size: 17)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.txt)),
                      const SizedBox(height: 2),
                      Text(n.message, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.txt3, height: 1.4)),
                      const SizedBox(height: 4),
                      Text(n.timeAgo.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.txt3, letterSpacing: 0.05)),
                    ])),
                    Container(width: 8, height: 8, decoration: BoxDecoration(
                      color: n.read ? AppColors.s4 : AppColors.neon,
                      shape: BoxShape.circle,
                      boxShadow: n.read ? null : [BoxShadow(color: AppColors.neon, blurRadius: 8)])),
                  ])),
              );
            })),
    ])));
  }
}
