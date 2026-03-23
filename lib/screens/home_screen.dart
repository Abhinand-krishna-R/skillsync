import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/skill_model.dart';
import '../models/ui_state.dart';
import '../models/module_model.dart';
import '../services/scoring_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/compact_role_tile.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;
    final hasSkills = state.skills.isNotEmpty;
    final unread = state.unreadCount;
    final scores = state.roleMatches;
    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final rolePrev = sorted.take(3).toList();
    final hasActiveModule = state.hasActiveModule;

    final score = state.score;
    // Greeting by time of day
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'GOOD MORNING' : hour < 17 ? 'GOOD AFTERNOON' : 'GOOD EVENING';

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
      // ── Header ─────────────────────────────────────────────
      Padding(padding: EdgeInsets.only(bottom: 16), child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neon.withValues(alpha: 0.7), letterSpacing: 0.12)),
            const SizedBox(height: 2),
            Text(p?.name.split(' ').first ?? 'Welcome', 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.txt, letterSpacing: -0.8)),
          ]),
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              child: Stack(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.s1, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.notifications_none_rounded, color: AppColors.txt3, size: 19)),
                if (unread > 0) Positioned(top: -2, right: -2, child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(color: AppColors.hot, borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: AppColors.hot.withValues(alpha: 0.6), blurRadius: 8)]),
                  child: Center(child: Text('$unread', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))))),
              ])),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.read<UiState>().setTab(AppTab.profile),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(gradient: AppColors.grad1, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.neon.withValues(alpha: 0.5), blurRadius: 16)]),
                child: Center(child: Text(p?.initials ?? '?',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white))))),
          ]),
        ],
      )),

      if (!hasSkills) ...[
        const _EmptyState(),
      ] else ...[
        // Suggested role banner (no target set yet)
        // Uses the role-specific match score — not the overall readiness score —
        // so the banner accurately reflects how well the user fits that specific role.
        if (p?.targetRoleSlug == null && score > 0)
          Builder(builder: (ctx) {
            final best = ScoringService.bestMatch(state.skills, state.allRoles);
            if (best == null) return const SizedBox.shrink();
            final matchScore = state.roleMatches[best.slug]?.score ?? score;
            return _SuggestedBanner(
              label: best.name,
              score: matchScore,
              onSet: () => context.read<AppState>().setTargetRole(best.slug, best.name),
            );
          }),

        // Readiness Hero
        _ReadinessHero(
          score: score,
          scoreLabel: p?.targetRoleLabel ?? ScoringService.bestMatch(state.skills, state.allRoles)?.name ?? 'your best role',
          matched: state.gapAnalysis['matched']?.length ?? 0,
          weak: state.gapAnalysis['weak']?.length ?? 0,
          missing: state.gapAnalysis['missing']?.length ?? 0,
        ),

        // Career Insight
        const _InsightCard(),

        // Skill Progress
        _SkillProgress(
          skills: state.skills.take(5).toList(),
          onViewAll: () => context.read<UiState>().setTab(AppTab.analyze),
        ),

        // Role Matches
        if (rolePrev.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(p?.targetRoleSlug != null ? 'OTHER GOOD MATCHES' : 'TOP CAREER MATCHES', 
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.12)),
              GestureDetector(
                onTap: () => context.read<UiState>().setTab(AppTab.explore),
                child: Row(children: [
                  Text('See more', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neon2)),
                  Icon(Icons.chevron_right_rounded, color: AppColors.neon2, size: 14),
                ])),
            ])),
          // Limit to top 3 as requested for cleaner UI
          ...rolePrev.map((e) => CompactRoleTile(
            slug: e.key,
            pct: e.value.score,
            isTarget: e.key == p?.targetRoleSlug,
          )),
        ],

        // Active Module
        if (hasActiveModule) _ActiveModuleCard(module: state.activeModule!),
      ],

      // ── Detect shortcuts ───────────────────────────────────
      const SizedBox(height: 16),
      SectionHeader('Detect My Skills'),
      SizedBox(height: 10),
      Row(children: [
        Expanded(child: _DetectCard(icon: Icons.description_outlined, label: 'Resume', color: AppColors.neon2,
          onTap: () { context.read<UiState>().setTab(AppTab.analyze); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<UiState>().setAnalyzeTab(AnalyzeTab.resume)); })),
        Expanded(child: _DetectCard(icon: Icons.checklist_rtl_rounded, label: 'MANUAL', color: AppColors.hot, 
          onTap: () { context.read<UiState>().setTab(AppTab.analyze); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<UiState>().setAnalyzeTab(AnalyzeTab.manual)); })),
      ]),
    ]);
  }
}

// ── Empty State ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: 12), padding: EdgeInsets.all(28),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [AppColors.neon.withValues(alpha: 0.15), AppColors.neon2.withValues(alpha: 0.1)]),
      border: Border.all(color: AppColors.neon.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(color: AppColors.neon.withValues(alpha: 0.15), border: Border.all(color: AppColors.neon.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(20)),
        child: Icon(Icons.track_changes_rounded, size: 34, color: AppColors.neon)),
      const SizedBox(height: 16),
      Text('Start your career journey', style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.txt, letterSpacing: -0.4)),
      const SizedBox(height: 8),
      Text('Analyse your skills to get your first career readiness score and role match',
        textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.txt3, height: 1.65)),
      SizedBox(height: 24),
      GestureDetector(
        onTap: () { context.read<UiState>().setTab(AppTab.analyze); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<UiState>().setAnalyzeTab(AnalyzeTab.resume)); },
        child: Container(height: 48,
          decoration: BoxDecoration(gradient: AppColors.grad1, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.neon.withValues(alpha: 0.4), blurRadius: 20, offset: Offset(0, 4))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.description_outlined, color: Colors.white, size: 18), const SizedBox(width: 8),
            Text('UPLOAD RESUME — INSTANT ANALYSIS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.04)),
          ]))),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => context.read<UiState>().setTab(AppTab.explore),
        child: Container(height: 44,
          decoration: BoxDecoration(border: Border.all(color: AppColors.s4), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.explore_outlined, color: AppColors.txt3, size: 16), SizedBox(width: 8),
            Text('EXPLORE CAREER ROLES', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.04)),
          ]))),
      SizedBox(height: 20),
      Text('Most users get their first score in under 2 minutes',
        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.txt3.withValues(alpha: 0.6))),
      
      const SizedBox(height: 16),
      Divider(color: AppColors.s3, height: 1),
      const SizedBox(height: 16),
      Text('WHAT YOU UNLOCK', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.txt3, letterSpacing: 0.8)),
      const SizedBox(height: 12),
      
      const _FeatureHint(
        icon: Icons.map_outlined,
        color: Color(0xFFA855F7), // neon
        title: 'Learning Roadmap',
        subtitle: '5-step personalised path to your target role',
      ),
      const _FeatureHint(
        icon: Icons.psychology_outlined,
        color: Color(0xFFFF3B6B), // hot
        title: 'Interview Insights',
        subtitle: 'Questions, tips and preparation for your role',
      ),
      const _FeatureHint(
        icon: Icons.track_changes_rounded,
        color: Color(0xFF06B6D4), // neon2
        title: 'Career Readiness Score',
        subtitle: 'See exactly how ready you are right now',
      ),
      const _FeatureHint(
        icon: Icons.explore_outlined,
        color: Color(0xFF10B981), // neon3
        title: 'Role Matching',
        subtitle: 'Matched against every career role instantly',
      ),
    ]),
  );
}

class _FeatureHint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _FeatureHint({required this.icon, required this.color, required this.title, required this.subtitle});

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.txt)),
          Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.txt3)),
        ])),
      ]),
    );
  }
}

// ── Suggested Banner ───────────────────────────────────────────
class _SuggestedBanner extends StatelessWidget {
  final String label; final int score; final VoidCallback onSet;
  const _SuggestedBanner({required this.label, required this.score, required this.onSet});
  @override Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: 12), padding: EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.neon3.withValues(alpha: 0.08), border: Border.all(color: AppColors.neon3.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Suggested Role', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.neon3)),
        Text('$label — $score% match',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.txt)),
        Text('Based on your current skills', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.txt3)),
      ])),
      GestureDetector(onTap: onSet,
        child: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.neon3.withValues(alpha: 0.15), border: Border.all(color: AppColors.neon3.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
          child: Text('SET TARGET', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neon3, letterSpacing: 0.04)))),
    ]),
  );
}

// ── Readiness Hero ─────────────────────────────────────────────
class _ReadinessHero extends StatelessWidget {
  final int score; final String scoreLabel; final int matched, weak, missing;
  const _ReadinessHero({required this.score, required this.scoreLabel, required this.matched, required this.weak, required this.missing});
  @override Widget build(BuildContext context) {
    final c = AppColors.scoreColor(score); final c2 = AppColors.scoreColor2(score);
    return Container(
      margin: EdgeInsets.only(bottom: 12), padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.neon.withValues(alpha: 0.2), AppColors.neon2.withValues(alpha: 0.15)]),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.neon.withValues(alpha: 0.15), blurRadius: 40)]),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CAREER READINESS SCORE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neon.withValues(alpha: 0.7), letterSpacing: 0.12)),
            SizedBox(height: 10),
            ShaderMask(blendMode: BlendMode.srcIn, shaderCallback: (b) => LinearGradient(colors: [c, c2]).createShader(Rect.fromLTWH(0,0,b.width,b.height)),
              child: RichText(text: TextSpan(children: [
                TextSpan(text: '$score', style: GoogleFonts.spaceGrotesk(fontSize: 76, fontWeight: FontWeight.w700, color: Colors.white, height: 0.9, letterSpacing: -3)),
                TextSpan(text: '%', style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
              ]))),
            const SizedBox(height: 8),
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(children: [
                TextSpan(text: 'Skill match vs ', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.txt3)),
                TextSpan(text: scoreLabel, 
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neon)),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _ScoreBadge('$matched Match', AppColors.neon3),
              const SizedBox(width: 6), _ScoreBadge('$weak Weak', AppColors.gold),
              const SizedBox(width: 6), _ScoreBadge('$missing Gap', AppColors.hot),
            ]),
          ]),
          ScoreRing(score: score, size: 88, strokeWidth: 8),
        ]),
        SizedBox(height: 10),
        Container(height: 4, decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(100)),
          child: FractionallySizedBox(widthFactor: score / 100, alignment: Alignment.centerLeft,
            child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [c, c2]), borderRadius: BorderRadius.circular(100), boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 12)])))),
      ]),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String label; final Color color;
  const _ScoreBadge(this.label, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: color)));
}

// ── Skill Progress ─────────────────────────────────────────────
class _SkillProgress extends StatelessWidget {
  final List<SkillModel> skills; final VoidCallback onViewAll;
  const _SkillProgress({required this.skills, required this.onViewAll});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.s1, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Skill Progress', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.txt, letterSpacing: -0.2)),
        SkillChip('${skills.length} skills'),
      ]),
      const SizedBox(height: 14),
      ...skills.map((s) => SkillBar(name: s.name, level: s.level, sublabel: s.label)),
      const SizedBox(height: 4),
      GestureDetector(onTap: onViewAll,
        child: Container(height: 36, decoration: BoxDecoration(border: Border.all(color: AppColors.s4), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text('VIEW FULL ANALYSIS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.04))))),
    ]),
  );
}

// ── Active Module Card ─────────────────────────────────────────
class _ActiveModuleCard extends StatelessWidget {
  final ModuleModel module;
  const _ActiveModuleCard({required this.module});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 4),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('CONTINUE LEARNING', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.12)),
      GestureDetector(onTap: () => context.read<UiState>().setTab(AppTab.roadmap),
        child: Row(children: [
          Text('Roadmap', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neon2)),
          Icon(Icons.chevron_right_rounded, color: AppColors.neon2, size: 14),
        ])),
    ]),
    SizedBox(height: 10),
    Container(padding: EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.neon.withValues(alpha: 0.15), AppColors.neon2.withValues(alpha: 0.1)]),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.neon.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.layers_rounded, color: AppColors.neon, size: 20)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(module.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.txt)),
          const SizedBox(height: 3),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${module.hours}h', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.txt3)),
              Text('·', style: TextStyle(color: AppColors.txt3)),
              ...module.tags.take(2).map((t) => SkillChip(t)),
            ],
          ),
          SizedBox(height: 8),
          Container(height: 4, decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(100)),
            child: FractionallySizedBox(widthFactor: module.progress / 100, alignment: Alignment.centerLeft,
              child: Container(decoration: BoxDecoration(gradient: AppColors.grad1, borderRadius: BorderRadius.circular(100), boxShadow: [BoxShadow(color: AppColors.neon.withValues(alpha: 0.6), blurRadius: 8)])))),
        ])),
        const SizedBox(width: 8),
        ShaderMask(blendMode: BlendMode.srcIn, shaderCallback: (b) => AppColors.grad1.createShader(Rect.fromLTWH(0,0,b.width,b.height)),
          child: Text('${module.progress}%', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white))),
      ]),
    ),
  ]);
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    final insight = context.watch<AppState>().generateInsight();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAREER INSIGHT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neon,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.txt,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detect Card ────────────────────────────────────────────────
class _DetectCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _DetectCard({required this.icon, required this.label, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.s1, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 8),
        Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.05)),
      ])));
}
