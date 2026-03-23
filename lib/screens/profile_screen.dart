import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/auth_state.dart';
import '../models/ui_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthState>();
    final ui = context.watch<UiState>();
    final p = state.profile;
    if (p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_rounded, size: 48, color: AppColors.txt3),
              const SizedBox(height: 16),
              Text('Profile Setup Required', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.txt)),
              const SizedBox(height: 8),
              Text('We couldn\'t find your profile data. You can try to re-initialize it below.',
                textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.txt3)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  try {
                    await auth.ensureProfileExists();
                    if (context.mounted) showToast(context, 'Profile initialized successfully!');
                  } catch (e) {
                    if (context.mounted) showToast(context, 'Repair failed: $e', warn: true);
                  }
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(gradient: AppColors.grad1, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('COMPLETE SETUP', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white))),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => auth.signOut(), child: Text('Sign Out', style: GoogleFonts.plusJakartaSans(color: AppColors.txt3))),
            ],
          ),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
      _GlassProfileCard(
        initials: p.initials,
        name: p.name.isEmpty ? 'Your Name' : p.name,
        role: p.currentRole.isEmpty ? 'Career path not set' : p.currentRole,
        email: p.email,
        education: p.education,
        memberSince: p.createdAt,
        onEdit: () => _showEditSheet(context, state),
      ),

      // ── Stats ────────────────────────────────────────────────
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _ProfileStat('${state.score}%', 'Readiness', AppColors.neon)),
          const SizedBox(width: 8),
          Expanded(child: _ProfileStat('${state.skills.length}', 'Skills', AppColors.neon2)),
          const SizedBox(width: 8),
          Expanded(child: _ProfileStat('${state.modules.where((m) => m.isCompleted).length}', 'Modules', AppColors.neon3)),
        ]),
        const SizedBox(height: 24),

        // Career Progress
        if (p.targetRoleSlug != null) ...[
          _SectionLabel('CAREER PROGRESS'),
          const SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.neon.withValues(alpha: 0.07), AppColors.s1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.neon.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.neon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.trending_up_rounded, color: AppColors.neon, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.targetRoleLabel ?? 'Not set',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.txt,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Next: ${(state.gapAnalysis['missing'] ?? []).isNotEmpty ? state.gapAnalysis['missing']!.first : "Keep learning!"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.txt3,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${state.score}%',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppColors.neon,
                      ),
                    ),
                    Text(
                      'Ready',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppColors.txt3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Skills overview
        _SectionLabel('TOP SKILLS'),
        const SizedBox(height: 10),
        if (state.skills.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No skills added yet', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.txt3)),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.s1,
              border: Border.all(color: AppColors.s3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ...state.skills.take(5).map((s) => SkillBar(name: s.name, level: s.level, sublabel: s.label)),
              ],
            ),
          ),
          if (state.skills.length > 5)
            GestureDetector(
              onTap: () => context.read<UiState>().setTab(AppTab.analyze),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View all ${state.skills.length} skills',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neon2),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.neon2),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),

        // Account menu
        _SectionLabel('ACCOUNT & SETTINGS'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.s1,
            border: Border.all(color: AppColors.s3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _ThemeToggleRow(
                icon: Icons.brightness_4_outlined,
                label: 'Dark Mode',
                iconColor: AppColors.neon,
                value: !ui.isLightMode,
                onChanged: (_) => ui.toggleTheme(),
              ),
              _MenuRow(Icons.notifications_outlined, 'Notifications', AppColors.neon2,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
              _MenuRow(Icons.privacy_tip_outlined, 'Privacy & Data', AppColors.neon3, () {}),
              _MenuRow(Icons.help_outline_rounded, 'Help & Support', AppColors.gold, () {}, isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _showLogoutSheet(context),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.hot.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.hot.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFFF6B8A), size: 15),
              const SizedBox(width: 8),
              Text('Sign Out', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B8A))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showDeleteAccountSheet(context),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.s4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text('Delete Account', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.txt3)),
            ),
          ),
        ),
      ])),
    ]);
  }

  void _showDeleteAccountSheet(BuildContext ctx) {
    showModalBottomSheet(context: ctx, backgroundColor: AppColors.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 44),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.s4, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 20),
          Container(width: 64, height: 64, decoration: BoxDecoration(border: Border.all(color: AppColors.hot, width: 2), shape: BoxShape.circle),
            child: Icon(Icons.delete_forever_rounded, color: AppColors.hot, size: 28)),
          const SizedBox(height: 16),
          Text('Delete Account?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.txt, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Text('This action is permanent. All your skills, roadmaps, and progress will be deleted forever.', 
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.txt3)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () async {
              Navigator.pop(sheetCtx);
              try {
                await ctx.read<AuthState>().deleteAccount();
              } catch (e) {
                showToast(ctx, 'Deletion failed. Try signing in again.');
              }
            },
            child: Container(height: 52, decoration: BoxDecoration(color: AppColors.hot, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('PERMANENTLY DELETE', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.04))))),
          const SizedBox(height: 12),
          GestureDetector(onTap: () => Navigator.pop(sheetCtx),
            child: Container(height: 44, decoration: BoxDecoration(border: Border.all(color: AppColors.s4), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('CANCEL', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.04))))),
        ])));
  }

  void _showEditSheet(BuildContext ctx, AppState state) {
    final p = state.profile!;
    final nameCtrl = TextEditingController(text: p.name);
    final locCtrl = TextEditingController(text: p.location);
    final eduCtrl = TextEditingController(text: p.education);
    final roleCtrl = TextEditingController(text: p.currentRole);
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: AppColors.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 44),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.s4, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 20),
          Text('Edit Profile', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.txt, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          _SheetInput(controller: nameCtrl, hint: 'Full name', icon: Icons.person_outline_rounded), const SizedBox(height: 12),
          _SheetInput(controller: locCtrl, hint: 'Location', icon: Icons.location_on_outlined), const SizedBox(height: 12),
          _SheetInput(controller: eduCtrl, hint: 'Education', icon: Icons.school_outlined), const SizedBox(height: 12),
          _SheetInput(controller: roleCtrl, hint: 'Current role or "Student"', icon: Icons.work_outline_rounded), const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              Navigator.pop(sheetCtx);
              await state.updateProfile({'name': nameCtrl.text, 'location': locCtrl.text, 'education': eduCtrl.text, 'currentRole': roleCtrl.text});
              showToast(ctx, 'Profile updated');
            },
            child: Container(height: 52, decoration: BoxDecoration(gradient: AppColors.grad1, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 16), const SizedBox(width: 8),
                Text('SAVE CHANGES', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.04)),
              ]))),
        ])));
  }

  void _showLogoutSheet(BuildContext ctx) {
    showModalBottomSheet(context: ctx, backgroundColor: AppColors.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 44),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.s4, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 20),
          Container(width: 64, height: 64, decoration: BoxDecoration(border: Border.all(color: AppColors.hot, width: 2), borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.logout_rounded, color: AppColors.hot, size: 28)),
          const SizedBox(height: 16),
          Text('Sign Out?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.txt, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('You will be returned to the login screen.', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.txt3)),
          SizedBox(height: 24),
          GestureDetector(
            onTap: () async { Navigator.pop(sheetCtx); await ctx.read<AuthState>().signOut(); },
            child: Container(height: 52, decoration: BoxDecoration(color: AppColors.hot.withValues(alpha: 0.1), border: Border.all(color: AppColors.hot.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.logout_rounded, color: Color(0xFFFF6B8A), size: 16), const SizedBox(width: 8),
                Text('YES, SIGN OUT', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFFF6B8A), letterSpacing: 0.04)),
              ]))),
          const SizedBox(height: 10),
          GestureDetector(onTap: () => Navigator.pop(sheetCtx),
            child: Container(height: 44, decoration: BoxDecoration(border: Border.all(color: AppColors.s4), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('CANCEL', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.04))))),
        ])));
  }
}


class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.neon, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.txt3, letterSpacing: 1.3)),
    ],
  );
}

class _ProfileStat extends StatelessWidget {
  final String value, label; final Color color;
  const _ProfileStat(this.value, this.label, this.color);
  @override Widget build(BuildContext context) => Container(
    height: 84,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.s1, // More solid looking cards
      border: Border.all(color: AppColors.s3),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        GradText(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
        ),
      const SizedBox(height: 4),
      Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.txt4, letterSpacing: 0.5), textAlign: TextAlign.center),
    ]));
}

class _MenuRow extends StatelessWidget {
  final IconData icon; final String label; final Color iconColor; final VoidCallback onTap; final bool isLast;
  const _MenuRow(this.icon, this.label, this.iconColor, this.onTap, {this.isLast = false});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppColors.s2))),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.txt2))),
        Icon(Icons.chevron_right_rounded, color: AppColors.txt4, size: 16),
      ])));
}

class _ThemeToggleRow extends StatelessWidget {
  final IconData icon; final String label; final Color iconColor; final bool value; final ValueChanged<bool> onChanged;
  const _ThemeToggleRow({required this.icon, required this.label, required this.iconColor, required this.value, required this.onChanged});
  
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.s2))),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.txt2))),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.neon,
        activeTrackColor: AppColors.neon.withValues(alpha: 0.3),
        inactiveTrackColor: AppColors.s3,
      ),
    ]));
}

class _SheetInput extends StatelessWidget {
  final TextEditingController controller; final String hint; final IconData icon;
  const _SheetInput({required this.controller, required this.hint, required this.icon});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.s2, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Padding(padding: const EdgeInsets.only(left: 14), child: Icon(icon, color: AppColors.txt3, size: 17)),
      Expanded(child: TextField(controller: controller, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.txt),
        decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.txt3), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)))),
    ]));
}

class _GlassProfileCard extends StatelessWidget {
  final String initials, name, role, email, education;
  final VoidCallback onEdit;
  final DateTime? memberSince;

  const _GlassProfileCard({
    required this.initials,
    required this.name,
    required this.role,
    required this.email,
    required this.education,
    required this.onEdit,
    this.memberSince,
  });

  @override
  Widget build(BuildContext context) {
    final year = (memberSince ?? DateTime.now()).year;
    return Container(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glass Background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E1B4B).withValues(alpha: 0.85),
                      const Color(0xFF0F172A).withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar — circle with indigo->sky gradient and glow
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF818CF8), Color(0xFF38BDF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF818CF8).withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Identity
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Member since $year',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit button — dark, subtle
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: Colors.white.withValues(alpha: 0.55),
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _TranslucentRow(icon: Icons.school_outlined, label: education),
                const SizedBox(height: 10),
                _TranslucentRow(icon: Icons.mail_outlined, label: email),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslucentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TranslucentRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigoAccent, size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
