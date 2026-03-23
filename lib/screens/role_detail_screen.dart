import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/roles_db.dart';
import '../models/skill_model.dart';
import '../models/ui_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/scoring_service.dart';

class RoleDetailScreen extends StatefulWidget {
  final String slug;
  final Map<String, dynamic>? roleData;
  const RoleDetailScreen({super.key, required this.slug, this.roleData});

  @override
  State<RoleDetailScreen> createState() => _RoleDetailScreenState();
}

class _RoleDetailScreenState extends State<RoleDetailScreen> {
  bool _isSettingTarget = false;

  @override Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final role = RolesDB.safeGet(widget.slug) ?? 
                 state.getDynamicRole(widget.slug) ??
                 (widget.roleData != null ? _parseRole(widget.roleData!) : null);
    if (role == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg),
        body: SingleChildScrollView(child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text('Role not found', style: TextStyle(color: AppColors.txt3))))),
      );
    }
    final match = state.roleMatches[widget.slug] ?? MatchResult(slug: widget.slug, score: 0, matchedSkills: [], weakSkills: [], missingSkills: []);
    final pct = match.score;
    final c = role.color;
    final isTarget = state.profile?.targetRoleSlug == widget.slug;

    return Scaffold(backgroundColor: AppColors.bg, body: SafeArea(child: CustomScrollView(slivers: [
      SliverAppBar(expandedHeight: 160, pinned: true, backgroundColor: AppColors.bg,
        flexibleSpace: FlexibleSpaceBar(background: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withValues(alpha: 0.25), AppColors.bg])),
          child: SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 50, 20, 20), child: Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: c.withValues(alpha: 0.15), border: Border.all(color: c.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(16)),
              child: Icon(roleIcon(role.icon), color: c, size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(role.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: AppColors.txt,
                      letterSpacing: -0.5)),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${role.category} · ${role.demand} demand',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppColors.txt3)),
                  SkillChip(
                      role.demand == 'Very High' ? 'High Demand' : role.demand,
                      variant: ChipVariant.green),
                ],
              ),
            ])),
          ]))))),
        leading: GestureDetector(onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.s1, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.chevron_left_rounded, color: AppColors.txt3))),
        actions: [if (isTarget) Container(margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(gradient: AppColors.grad1, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text('TARGET', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.06))))],
      ),

      SliverPadding(padding: EdgeInsets.fromLTRB(16, 0, 16, 100), sliver: SliverList(delegate: SliverChildListDelegate([
        // Match Score
        if (state.skills.isNotEmpty) Container(margin: EdgeInsets.only(bottom: 12), padding: EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [c.withValues(alpha: 0.2), c.withValues(alpha: 0.08)]),
            border: Border.all(color: c.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            ScoreRing(score: pct, size: 80, strokeWidth: 7),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your Match Score', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.txt3)), const SizedBox(height: 4),
              Text('$pct% skill match', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 20, color: c)), const SizedBox(height: 2),
              Text('vs required skills for this role', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.txt3)),
            ])),
          ])),

        // Set target / current target button
        if (!isTarget)
          GestureDetector(
            onTap: () async {
              if (_isSettingTarget) return;
              setState(() => _isSettingTarget = true);
              try {
                await context.read<AppState>().setTargetRole(widget.slug, role.name);
                if (mounted) {
                  Navigator.pop(context);
                  showToast(context, 'Target set: ${role.name}');
                  context.read<UiState>().setTab(AppTab.roadmap); // go to roadmap
                }
              } catch (e) {
                debugPrint('RoleDetailScreen: setTargetRole error: $e');
                if (mounted) {
                  showToast(
                    context,
                    'Could not generate roadmap. Please try again.',
                    warn: true,
                  );
                }
              } finally {
                if (mounted) setState(() => _isSettingTarget = false);
              }
            },
            child: Container(margin: EdgeInsets.only(bottom: 12), height: 52,
              decoration: BoxDecoration(gradient: AppColors.grad1, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.neon.withValues(alpha: 0.4), blurRadius: 20, offset: Offset(0,4))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_isSettingTarget)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                else ...[
                  const Icon(Icons.track_changes_rounded, color: Colors.white, size: 17), const SizedBox(width: 8),
                  Text('SET AS TARGET ROLE', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.04)),
                ]
              ])))
        else
          GestureDetector(
            onLongPress: () async {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.s1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.s3)),
                  title: Text('Clear Target Role?', style: GoogleFonts.spaceGrotesk(color: AppColors.txt, fontWeight: FontWeight.bold)),
                  content: Text('Are you sure you want to stop targeting this role? Your progress will be archived.', style: GoogleFonts.plusJakartaSans(color: AppColors.txt2, fontSize: 13, height: 1.5)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.txt3, fontWeight: FontWeight.w600))),
                    TextButton(onPressed: () async {
                      Navigator.pop(context);
                      await context.read<AppState>().clearTargetRole();
                      if (mounted) showToast(context, 'Target cleared');
                    }, child: Text('Clear', style: GoogleFonts.plusJakartaSans(color: AppColors.hot, fontWeight: FontWeight.bold))),
                  ],
                )
              );
            },
            child: Container(margin: EdgeInsets.only(bottom: 12), height: 52,
              decoration: BoxDecoration(color: AppColors.neon.withValues(alpha: 0.1), border: Border.all(color: AppColors.neon.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_rounded, color: AppColors.neon, size: 17), const SizedBox(width: 8),
                Text('CURRENT TARGET ROLE', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.neon, letterSpacing: 0.04)),
              ]))),

        // Salary & Demand
        Row(children: [
          Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.s1, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('INDIA SALARY', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.06)), const SizedBox(height: 4),
              Text(role.salary, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.neon3)),
            ]))),
          const SizedBox(width: 8),
          Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.s1, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('DEMAND', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.txt3, letterSpacing: 0.06)), const SizedBox(height: 4),
              Text(role.demand, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.neon2)),
            ]))),
        ]),
        const SizedBox(height: 12),

        // About
        _InfoCard('About this Role', child: Text(role.description, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.txt3, height: 1.65))),

        // Qualifications
        if (role.qualificationRequired || role.qualifications.isNotEmpty || role.qualificationNote.isNotEmpty)
          _InfoCard(
            'Qualifications & Degrees',
            badge: role.qualificationRequired 
              ? SkillChip('Degree Required', variant: ChipVariant.amber)
              : SkillChip('Degree Optional', variant: ChipVariant.green),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (role.qualifications.isNotEmpty) ...[
                  ...role.qualifications.map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.school_rounded, size: 16, color: AppColors.txt3),
                        const SizedBox(width: 8),
                        Expanded(child: Text(q, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.txt))),
                      ]
                    )
                  )),
                  const SizedBox(height: 8),
                ],
                if (role.qualificationNote.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: c),
                      const SizedBox(width: 8),
                      Expanded(child: Text(role.qualificationNote, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.txt2, height: 1.5))),
                    ])
                  )
              ]
            )
          ),

        // Required Skills
        _InfoCard('Required Skills', child: Column(children: role.requiredSkills.map((req) {
          final isMatched = match.matchedSkills.contains(req);
          final isWeak = match.weakSkills.contains(req);
          final hasIt = isMatched || isWeak;
          
          // Find actual skill level from user profile
          final userSkill = state.skills.firstWhere((s) => RolesDB.isMatch(s.name, req), orElse: () => SkillModel(id: '', name: '', level: 0));
          
          return Padding(padding: EdgeInsets.only(bottom: 10), child: Row(children: [
            Container(width: 24, height: 24, decoration: BoxDecoration(
              color: isMatched ? AppColors.neon3.withValues(alpha: 0.15) : (isWeak ? AppColors.gold.withValues(alpha: 0.15) : AppColors.hot.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(6)),
              child: Icon(isMatched ? Icons.check_rounded : (isWeak ? Icons.warning_amber_rounded : Icons.close_rounded),
                size: 14, color: isMatched ? AppColors.neon3 : (isWeak ? AppColors.gold : AppColors.hot))),
            const SizedBox(width: 10),
            Expanded(child: Text(req, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.txt2))),
            if (hasIt) Text('${userSkill.level}%', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: isMatched ? AppColors.neon3 : AppColors.gold)),
          ]));
        }).toList())),

        // Tools
        _InfoCard('Tools & Technologies', child: Wrap(spacing: 6, runSpacing: 6, children: role.tools.map((t) => SkillChip(t)).toList())),

        // AI Learning Plan
        _InfoCard('AI Learning Plan', badge: Row(children: [Icon(Icons.auto_awesome_rounded, size: 10, color: AppColors.neon3), const SizedBox(width: 4), SkillChip('AI Enhanced', variant: ChipVariant.green)]),
          child: Column(children: role.aiTips.asMap().entries.map((e) => Padding(padding: EdgeInsets.only(bottom: e.key < role.aiTips.length - 1 ? 10 : 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 24, height: 24, margin: const EdgeInsets.only(right: 12, top: 2), decoration: BoxDecoration(gradient: AppColors.grad1, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('${e.key + 1}', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)))),
              Expanded(child: Text(e.value, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.txt3, height: 1.65))),
            ]))).toList())),

        // Go to roadmap CTA
        GestureDetector(onTap: () { Navigator.pop(context); context.read<UiState>().setTab(AppTab.roadmap); },
          child: Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.neon.withValues(alpha: 0.15), AppColors.neon2.withValues(alpha: 0.1)]),
            border: Border.all(color: AppColors.neon.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.map_outlined, color: AppColors.hot, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ready to start learning?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.txt, letterSpacing: -0.3)),
                Text('View your personalised roadmap', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.txt3)),
              ])),
              Icon(Icons.arrow_forward_rounded, color: AppColors.hot, size: 20),
            ]))),
      ]))),
    ])));
  }

  CareerRole _parseRole(Map<String, dynamic> data) {
    final requiredSkills = List<String>.from(
        data['requiredSkills'] ?? data['skills'] ?? []);

    // Read AI-generated weights — fall back to equal weights if absent
    final rawWeights = data['weights'] as Map<String, dynamic>?;
    final Map<String, double> weights = rawWeights != null
        ? rawWeights.map((k, v) => MapEntry(k, (v as num).toDouble()))
        : {for (final s in requiredSkills) s: 1.0};

    // Read AI-generated requiredLevels — fall back to 75 if absent
    final rawLevels = data['requiredLevels'] as Map<String, dynamic>?;
    final Map<String, int> requiredLevels = rawLevels != null
        ? rawLevels.map((k, v) => MapEntry(k, (v as num).toInt()))
        : {for (final s in requiredSkills) s: 75};

    return CareerRole(
      slug: widget.slug,
      name: data['title'] ?? data['name'] ?? 'Unknown Role',
      icon: data['icon'] ?? 'work_outline',
      category: data['category'] ?? 'Career',
      demand: data['demand'] ?? 'High',
      salary: data['salary'] ?? data['salaryRange'] ?? '₹4–20 LPA',
      description: data['description'] ?? '',
      requiredSkills: requiredSkills,
      weights: weights,
      requiredLevels: requiredLevels,
      tools: List<String>.from(data['tools'] ?? []),
      aiTips: List<String>.from(data['aiTips'] ?? []),
      color: AppColors.neon2,
      qualificationRequired: data['qualificationRequired'] as bool? ?? false,
      qualifications: List<String>.from(data['qualifications'] ?? []),
      qualificationNote: data['qualificationNote'] as String? ?? '',
      source: data['source'] ?? 'ai',
      createdAt: data['createdAt'] != null ? DateTime.tryParse(data['createdAt']) : null,
      difficulty: (data['difficulty'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title; final Widget child; final Widget? badge;
  const _InfoCard(this.title, {required this.child, this.badge});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: AppColors.s1, border: Border.all(color: AppColors.s3), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(title, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.txt, letterSpacing: -0.2))),
        if (badge != null) Flexible(child: badge!),
      ]),
      const SizedBox(height: 12),
      child,
    ]));
}
