import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/module_model.dart';
import '../models/ui_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'module_detail_screen.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiState>();
    return Column(children: [
      const SkillTopBar('Learning Roadmap'),
      AppTabs(
        tabs: const ['My Roadmap', 'Interview Insights'],
        current: ui.roadmapTab.index,
        onChanged: (t) => context.read<UiState>().setRoadmapTab(RoadmapTab.values[t]),
      ),
      Expanded(
        child: ui.roadmapTab == RoadmapTab.path
            ? const _RoadmapList()
            : const _InterviewInsights(),
      ),
    ]);
  }
}

// ── ROADMAP TAB ────────────────────────────────────────────────

class _RoadmapList extends StatelessWidget {
  const _RoadmapList();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;
    // Only use targetRoleLabel when a role is actually set.
    // Never fall back to bestMatch here — that caused the roadmap hero to say
    // "TARGETING Flutter Developer" even when the user had set no target at all.
    final target = p?.targetRoleLabel ?? 'Career Path not set';
    final hasTarget = p?.targetRoleSlug != null;

    final doneCount = state.modules.where((m) => m.isCompleted).length;
    final totalHrs = state.modules.fold(0, (a, m) => a + m.hours);
    final total = state.modules.length;
    final progress = total > 0 ? doneCount / total : 0.0;
    final sorted = (state.modules.toList()
      ..sort((a, b) => a.order.compareTo(b.order)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
      children: [
        // ── Hero Card ──────────────────────────────────────────
        _RoadmapHero(
          target: target,
          progress: progress,
          doneCount: doneCount,
          total: total,
          totalHrs: totalHrs,
          hasTarget: hasTarget,
        ),
        const SizedBox(height: 8),

        // ── Module Timeline ────────────────────────────────────
        if (state.modules.isEmpty)
          const _NoModulesPlaceholder()
        else
          _TimelineList(modules: sorted),

        // ── Archived Roadmaps ──────────────────────────────────
        if (p != null && p.archivedRoadmaps.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'PREVIOUS ROADMAPS',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.txt3,
                letterSpacing: 0.12),
          ),
          const SizedBox(height: 10),
          ...p.archivedRoadmaps.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.s1,
                    border: Border.all(color: AppColors.s3),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: AppColors.s3,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.archive_outlined,
                        color: AppColors.txt3, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['label'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.txt)),
                          Text(
                              '${r['completedModules']}/${r['totalModules']} modules completed',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: AppColors.txt3)),
                        ]),
                  ),
                  SkillChip('Archived', variant: ChipVariant.amber),
                ]),
              )),
        ],
      ],
    );
  }
}

// ── Roadmap Hero Card ──────────────────────────────────────────
class _RoadmapHero extends StatelessWidget {
  final String target;
  final double progress;
  final int doneCount, total, totalHrs;
  final bool hasTarget;

  const _RoadmapHero({
    required this.target,
    required this.progress,
    required this.doneCount,
    required this.total,
    required this.totalHrs,
    this.hasTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.neon.withValues(alpha: 0.18),
            AppColors.neon2.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.neon.withValues(alpha: 0.12), blurRadius: 30)
        ],
      ),
      child: Row(
        children: [
          // Left: text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.neon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasTarget ? 'TARGETING' : 'NO TARGET SET',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neon,
                        letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  target,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.txt,
                      letterSpacing: -0.5,
                      height: 1.2),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _HeroStat(
                    icon: Icons.layers_outlined,
                    value: '$doneCount/$total',
                    label: 'Modules',
                    color: AppColors.neon,
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: AppColors.s4,
                  ),
                  _HeroStat(
                    icon: Icons.schedule_outlined,
                    value: '${totalHrs}h',
                    label: 'Total',
                    color: AppColors.neon2,
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: AppColors.s4,
                  ),
                  _HeroStat(
                    icon: Icons.emoji_events_outlined,
                    value: '${(progress * 100).round()}%',
                    label: 'Done',
                    color: AppColors.neon3,
                  ),
                ]),
                const SizedBox(height: 14),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    height: 6,
                    color: AppColors.s3,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.grad1,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.neon.withValues(alpha: 0.6),
                                blurRadius: 8)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Right: big score ring
          const SizedBox(width: 16),
          ScoreRing(
            score: (progress * 100).round(),
            size: 80,
            strokeWidth: 7,
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _HeroStat(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(value,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.txt)),
          ]),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.txt3)),
        ],
      );
}

// ── Timeline List ──────────────────────────────────────────────
class _TimelineList extends StatelessWidget {
  final List<ModuleModel> modules;
  const _TimelineList({required this.modules});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: modules.asMap().entries.map((e) {
        final isLast = e.key == modules.length - 1;
        return _TimelineTile(
          module: e.value,
          index: e.key,
          isLast: isLast,
        );
      }).toList(),
    );
  }
}

// ── Timeline Tile ──────────────────────────────────────────────
class _TimelineTile extends StatelessWidget {
  final ModuleModel module;
  final int index;
  final bool isLast;

  const _TimelineTile({
    required this.module,
    required this.index,
    required this.isLast,
  });

  // Color per step — gives the journey a progression feel
  Color _stepColor(int i) {
    const colors = [
      Color(0xFFA855F7), // purple
      Color(0xFF06B6D4), // cyan
      Color(0xFF10B981), // green
      Color(0xFFF59E0B), // amber
      Color(0xFFFF3B6B), // hot pink
    ];
    return colors[i % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final m = module;
    final isCompleted = m.isCompleted;
    final isActive = m.isActive;
    final isLocked = m.isLocked;
    final color = _stepColor(index);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left: Timeline indicator ───────────────────
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // Circle indicator
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.neon3.withValues(alpha: 0.15)
                        : isActive
                            ? color.withValues(alpha: 0.15)
                            : AppColors.s2,
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.neon3
                          : isActive
                              ? color
                              : AppColors.s4,
                      width: isActive ? 2 : 1.5,
                    ),
                    boxShadow: isActive
                        ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)]
                        : isCompleted
                            ? [BoxShadow(color: AppColors.neon3.withValues(alpha: 0.3), blurRadius: 8)]
                            : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check_rounded,
                            color: AppColors.neon3, size: 16)
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isActive ? color : AppColors.txt3,
                            ),
                          ),
                  ),
                ),
                // Connector line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isCompleted
                              ? [
                                  AppColors.neon3.withValues(alpha: 0.6),
                                  AppColors.neon3.withValues(alpha: 0.2),
                                ]
                              : [
                                  AppColors.s4,
                                  AppColors.s3,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Right: Module card ─────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: GestureDetector(
                onTap: isLocked
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ModuleDetailScreen(
                                module: m, initialIndex: index),
                          ),
                        ),
                child: Opacity(
                  opacity: isLocked ? 0.4 : 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isActive
                          ? color.withValues(alpha: 0.06)
                          : AppColors.s1,
                      border: Border.all(
                        color: isActive
                            ? color.withValues(alpha: 0.4)
                            : isCompleted
                                ? AppColors.neon3.withValues(alpha: 0.2)
                                : AppColors.s3,
                        width: isActive ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: color.withValues(alpha: 0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4))
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status chip + hours
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (isCompleted)
                                    _StatusPill('COMPLETED', AppColors.neon3)
                                  else if (isActive)
                                    _StatusPill('IN PROGRESS', color)
                                  else
                                    _StatusPill('LOCKED', AppColors.txt4),
                                  Row(children: [
                                    Icon(Icons.schedule_outlined,
                                        size: 11, color: AppColors.txt3),
                                    const SizedBox(width: 3),
                                    Text('${m.hours}h',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: AppColors.txt3,
                                            fontWeight: FontWeight.w600)),
                                    if (!isLocked) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.chevron_right_rounded,
                                          color: isActive ? color : AppColors.txt4,
                                          size: 16),
                                    ],
                                  ]),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Title
                              Text(
                                m.title
                                    .replaceAll(RegExp(r': .+'), '')
                                    .trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.txt,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Skill tags
                              if (m.tags.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: m.tags
                                      .take(3)
                                      .map(
                                        (t) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            t,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                        // Active module progress bar at bottom
                        if (isActive)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(14)),
                            child: Container(
                              height: 4,
                              color: AppColors.s3,
                              child: FractionallySizedBox(
                                widthFactor: m.progress / 100,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: [color, color.withValues(alpha: 0.6)]),
                                    boxShadow: [
                                      BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 6)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Completed: done checkmark bar
                        if (isCompleted)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(14)),
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: AppColors.grad3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5),
        ),
      );
}

class _NoModulesPlaceholder extends StatelessWidget {
  const _NoModulesPlaceholder();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: AppColors.neon.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.map_outlined, size: 28, color: AppColors.neon),
            ),
            const SizedBox(height: 16),
            Text('No roadmap yet',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.txt)),
            const SizedBox(height: 6),
            Text('Set a target role to generate your path',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.txt3)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.read<UiState>().setTab(AppTab.explore),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                    gradient: AppColors.grad1,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.neon.withValues(alpha: 0.3),
                          blurRadius: 16)
                    ]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.explore_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 8),
                  Text('EXPLORE ROLES',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.04)),
                ]),
              ),
            ),
          ]),
        ),
      );
}

// ── INTERVIEW INSIGHTS TAB ────────────────────────────────────

class _InterviewInsights extends StatefulWidget {
  const _InterviewInsights();

  @override
  State<_InterviewInsights> createState() => _InterviewInsightsState();
}

class _InterviewInsightsState extends State<_InterviewInsights> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _loadedSlug;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    final slug = state.profile?.targetRoleSlug;
    if (slug != null && slug != _loadedSlug && !_loading) {
      _fetch(state, slug);
    }
  }

  Future<void> _fetch(AppState state, String slug) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final roleLabel = state.profile?.targetRoleLabel ?? slug.replaceAll('_', ' ');
      final result = await state.generateInterviewInsights(roleLabel);
      
      if (!mounted || slug != (context.read<AppState>().profile?.targetRoleSlug)) return;

      setState(() {
        _data = result;
        _loadedSlug = slug;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('_InterviewInsightsState._fetch error: $e');
      setState(() {
        _error = 'Failed to load insights. Tap to retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final roleLabel = state.profile?.targetRoleLabel;

    if (roleLabel == null) {
      return _NoRolePrompt(onTap: () => context.read<UiState>().setTab(AppTab.explore));
    }

    if (_loading) return const _InsightsShimmer();

    if (_error != null || _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              _error != null ? Icons.error_outline_rounded : Icons.psychology_outlined, 
              size: 40, 
              color: _error != null ? AppColors.hot : AppColors.txt3
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Tap to load insights',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.txt)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                final slug = state.profile?.targetRoleSlug;
                if (slug != null) _fetch(state, slug);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                    gradient: _error != null ? AppColors.grad4 : AppColors.grad1,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_error != null ? 'Retry' : 'Generate Insights',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ]),
        ),
      );
    }

    final overview = _data!['overview'] as String? ?? '';
    final types = List<String>.from(_data!['interview_types'] ?? []);
    final questions = List<String>.from(_data!['common_questions'] ?? []);
    final tips = List<String>.from(_data!['preparation_tips'] ?? []);
    final calm = List<String>.from(_data!['calm_advice'] ?? []);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // ── Hero Banner ────────────────────────────────────────
        _InsightsHero(roleLabel: roleLabel),
        const SizedBox(height: 16),

        // ── Overview ──────────────────────────────────────────
        if (overview.isNotEmpty) ...[
          _SectionLabel('What to expect'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.s1,
              border: Border.all(color: AppColors.neon2.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.neon2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline_rounded,
                    color: AppColors.neon2, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(overview,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.txt2,
                        height: 1.65)),
              ),
            ]),
          ),
          const SizedBox(height: 20),
        ],

        // ── Interview Types ─────────────────────────────────────
        if (types.isNotEmpty) ...[
          _SectionLabel('Interview formats'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.asMap().entries.map((e) {
              final colors = [
                AppColors.neon,
                AppColors.neon2,
                AppColors.neon3,
                AppColors.gold,
              ];
              final c = colors[e.key % colors.length];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  border: Border.all(color: c.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(e.value,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: c)),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // ── Common Questions ───────────────────────────────────
        if (questions.isNotEmpty) ...[
          _SectionLabel('Questions you may hear'),
          const SizedBox(height: 4),
          Text('Tap any question to see how to approach it',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.txt3)),
          const SizedBox(height: 12),
          ...questions.asMap().entries.map(
                (e) => _ExpandableQuestion(
                    number: e.key + 1,
                    question: e.value,
                    // Map preparation tips to questions by index
                    // so each expanded card shows a relevant tip
                    prepTip: tips.isNotEmpty
                        ? tips[e.key % tips.length]
                        : null,
                  ),
              ),
          const SizedBox(height: 8),
        ],

        // ── Preparation Tips ────────────────────────────────────
        if (tips.isNotEmpty) ...[
          _SectionLabel('How to prepare'),
          const SizedBox(height: 10),
          ...tips.asMap().entries.map(
                (e) => _PrepStep(number: e.key + 1, tip: e.value),
              ),
          const SizedBox(height: 8),
        ],

        // ── Calm Advice ─────────────────────────────────────────
        if (calm.isNotEmpty) ...[
          _SectionLabel('Stay confident'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.neon3.withValues(alpha: 0.12),
                  AppColors.neon2.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: AppColors.neon3.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.neon3.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.self_improvement_rounded,
                        color: AppColors.neon3, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('Mindset tips',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.txt)),
                ]),
                const SizedBox(height: 14),
                ...calm.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(right: 10, top: 1),
                              decoration: BoxDecoration(
                                color: AppColors.neon3.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.check_rounded,
                                  color: AppColors.neon3, size: 12),
                            ),
                            Expanded(
                              child: Text(c,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppColors.txt2,
                                      height: 1.55)),
                            ),
                          ]),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Interview Insights Hero ────────────────────────────────────
class _InsightsHero extends StatelessWidget {
  final String roleLabel;
  const _InsightsHero({required this.roleLabel});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.hot.withValues(alpha: 0.18),
              AppColors.neon.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.hot.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppColors.hot.withValues(alpha: 0.1), blurRadius: 20)
          ],
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.hot.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hot.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.psychology_rounded, color: AppColors.hot, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.hot.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('INTERVIEW PREP',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.hot,
                        letterSpacing: 0.7)),
              ),
              const SizedBox(height: 6),
              Text(roleLabel,
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.txt,
                      letterSpacing: -0.5)),
              const SizedBox(height: 3),
              Text('Curated insights to help you land the role',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppColors.txt3)),
            ]),
          ),
        ]),
      );
}

// ── Expandable Question Card ───────────────────────────────────
class _ExpandableQuestion extends StatefulWidget {
  final int number;
  final String question;
  // AI-sourced preparation tip mapped from interview insights — null until loaded
  final String? prepTip;
  const _ExpandableQuestion({required this.number, required this.question, this.prepTip});

  @override
  State<_ExpandableQuestion> createState() => _ExpandableQuestionState();
}

class _ExpandableQuestionState extends State<_ExpandableQuestion>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  // Returns a hint sourced from the AI-generated preparation tips if available,
  // falling back to keyword-based hints only as a last resort.
  String _getApproachHint() {
    // Use tip mapped by question index if available from parent
    if (widget.prepTip != null && widget.prepTip!.isNotEmpty) {
      return widget.prepTip!;
    }

    // Keyword fallback — only fires when AI tips are not yet loaded
    final q = widget.question.toLowerCase();
    if (q.contains('yourself') || q.contains('background') || q.contains('introduce')) {
      return 'Keep it professional and focused. Cover your experience, key skills, and what excites you about this role. Aim for 90 seconds.';
    }
    if (q.contains('challenge') || q.contains('difficult') || q.contains('problem') || q.contains('obstacle')) {
      return 'Use the STAR method: Situation, Task, Action, Result. Focus on what YOU specifically did and what you learned.';
    }
    if (q.contains('strength') || q.contains('weakness') || q.contains('improve')) {
      return 'Be honest but strategic. For weaknesses, always pair them with a concrete step you are taking to improve.';
    }
    if (q.contains('why') && (q.contains('company') || q.contains('role') || q.contains('join') || q.contains('this'))) {
      return 'Research the company mission beforehand. Connect their goals to your career direction — show genuine fit, not just availability.';
    }
    if (q.contains('team') || q.contains('collaborate') || q.contains('conflict') || q.contains('colleague')) {
      return 'Show you value communication. Give a specific real example — interviewers remember stories, not generalities.';
    }
    if (q.contains('project') || q.contains('build') || q.contains('ship') || q.contains('deliver')) {
      return 'Walk through your role specifically. What decisions did you own? What trade-offs did you make? What would you do differently?';
    }
    return 'Pause before answering — a moment to think shows confidence, not hesitation. Be specific with examples from your actual experience.';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _expanded
              ? AppColors.hot.withValues(alpha: 0.06)
              : AppColors.s1,
          border: Border.all(
            color: _expanded
                ? AppColors.hot.withValues(alpha: 0.3)
                : AppColors.s3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10, top: 1),
                    decoration: BoxDecoration(
                      color: _expanded
                          ? AppColors.hot.withValues(alpha: 0.15)
                          : AppColors.s2,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.number}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _expanded ? AppColors.hot : AppColors.txt3,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.txt,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _expanded ? AppColors.hot : AppColors.txt3,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded hint section
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.hot.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.hot.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        color: AppColors.gold, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getApproachHint(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.txt2,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preparation Step ───────────────────────────────────────────
class _PrepStep extends StatelessWidget {
  final int number;
  final String tip;
  const _PrepStep({required this.number, required this.tip});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.s1,
          border: Border.all(color: AppColors.s3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 12, top: 1),
            decoration: BoxDecoration(
              gradient: AppColors.grad1,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: AppColors.neon.withValues(alpha: 0.3),
                    blurRadius: 8)
              ],
            ),
            child: Center(
              child: Text(
                '$number',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ),
          ),
          Expanded(
            child: Text(tip,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.txt2, height: 1.55)),
          ),
        ]),
      );
}

// ── Section Label ──────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.txt3,
            letterSpacing: 0.12),
      );
}

// ── Shimmer Loading ────────────────────────────────────────────
class _InsightsShimmer extends StatefulWidget {
  const _InsightsShimmer();

  @override
  State<_InsightsShimmer> createState() => _InsightsShimmerState();
}

class _InsightsShimmerState extends State<_InsightsShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 0.8).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 90),
          children: [
            _ShimmerBox(height: 90, opacity: _anim.value),
            const SizedBox(height: 16),
            _ShimmerBox(height: 60, opacity: _anim.value),
            const SizedBox(height: 12),
            _ShimmerBox(height: 120, opacity: _anim.value),
            const SizedBox(height: 12),
            _ShimmerBox(height: 80, opacity: _anim.value),
            const SizedBox(height: 12),
            _ShimmerBox(height: 100, opacity: _anim.value),
          ],
        ),
      );
}

class _ShimmerBox extends StatelessWidget {
  final double height, opacity;
  const _ShimmerBox({required this.height, required this.opacity});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.s2,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
}

// ── No Role Prompt ─────────────────────────────────────────────
class _NoRolePrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _NoRolePrompt({required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.hot.withValues(alpha: 0.1),
                border:
                    Border.all(color: AppColors.hot.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.psychology_outlined,
                  size: 30, color: AppColors.hot),
            ),
            const SizedBox(height: 16),
            Text('No role selected yet',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.txt,
                    letterSpacing: -0.4)),
            const SizedBox(height: 8),
            Text(
                'Set a target role to unlock\npersonalised interview insights',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.txt3,
                    height: 1.55)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.hot, AppColors.gold]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.hot.withValues(alpha: 0.3),
                          blurRadius: 16)
                    ]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.explore_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('EXPLORE ROLES',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.04)),
                ]),
              ),
            ),
          ]),
        ),
      );
}
