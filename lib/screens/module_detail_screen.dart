import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_state.dart';
import '../models/module_model.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../widgets/common.dart';

class ModuleDetailScreen extends StatefulWidget {
  final ModuleModel module;
  final int? initialIndex;
  const ModuleDetailScreen({super.key, required this.module, this.initialIndex});

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    // Persistent task state is now managed in AppState.
  }

  // Builds dynamic prerequisites from actual module data
  List<Widget> _buildPrerequisites({
    required ModuleModel module,
    required int moduleIndex,
    required List<ModuleModel> modules,
  }) {
    final items = <Widget>[];

    if (moduleIndex == 0) {
      // First module — no prior module needed
      items.add(_PrereqRow(text: 'No prior module required', met: true));
    } else {
      // Show the actual previous module title as the prerequisite
      final sortedModules = List<ModuleModel>.from(modules)
        ..sort((a, b) => a.order.compareTo(b.order));
      final prevIndex = moduleIndex - 1;
      if (prevIndex >= 0 && prevIndex < sortedModules.length) {
        final prev = sortedModules[prevIndex];
        final prevTitle = prev.title
            .replaceAll(RegExp(r': .+'), '')
            .trim();
        items.add(_PrereqRow(
          text: 'Complete: $prevTitle',
          met: prev.isCompleted,
        ));
      }
    }

    // Add skill prerequisites from module tags if any exist
    if (module.tags.isNotEmpty) {
      items.add(_PrereqRow(
        text: 'Familiarity with: ${module.tags.take(2).join(", ")}',
        met: true,
      ));
    }

    return items;
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      // Direct launch without canLaunchUrl check to avoid intent declaration issues on Android
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        showToast(context, 'Could not launch $url');
      }
    } catch (e) {
      if (mounted) showToast(context, 'Error launching link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    final state = context.watch<AppState>();
    final isDone = m.status == ModuleStatus.completed;
    final isActive = m.status == ModuleStatus.active;
    final isLocked = m.status == ModuleStatus.locked;

    // Find module index for display.
    // Fallback indexWhere can return -1 if the stream hasn't hydrated yet;
    // clamp to 0 so the header never shows "MODULE 0".
    final rawIndex = (widget.initialIndex != null && widget.initialIndex != -1)
        ? widget.initialIndex!
        : state.modules.indexWhere((mod) => mod.id == m.id);
    final moduleIndex = rawIndex < 0 ? 0 : rawIndex;
    final taskChecked = state.getModuleTasks(m.id, m.practice.length);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: AppColors.bg,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.txt),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.neon.withOpacity(0.1), AppColors.bg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.neon3.withOpacity(0.15)
                                : AppColors.neon.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            isDone
                                ? 'COMPLETED'
                                : isActive
                                    ? 'IN PROGRESS'
                                    : 'LOCKED',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDone ? AppColors.neon3 : AppColors.neon,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'MODULE ${moduleIndex + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.txt3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.txt,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Stats Row + Overview ─────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatCard(
                              value: '${m.hours}h',
                              label: 'Learning',
                              color: AppColors.neon,
                              icon: Icons.schedule_outlined),
                          const SizedBox(width: 8),
                          _StatCard(
                              value: '${m.tags.length}',
                              label: 'Skills',
                              color: AppColors.neon2,
                              icon: Icons.layers_outlined),
                          const SizedBox(width: 8),
                          _StatCard(
                              value: '${m.progress}%',
                              label: 'Progress',
                              color: AppColors.neon3,
                              icon: Icons.track_changes_rounded),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'OBJECTIVE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.txt3,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        m.description,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: AppColors.txt2,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Sectioned Overview ──
                      _OverviewSubSection(
                        title: 'What You\'ll Learn',
                        color: AppColors.neon,
                        children: m.tags
                            .map((item) => _BulletPoint(
                                  text: item,
                                  color: AppColors.neon,
                                ))
                            .toList(),
                      ),

                      _OverviewSubSection(
                        title: 'Prerequisites',
                        color: AppColors.gold,
                        children: _buildPrerequisites(
                          module: m,
                          moduleIndex: moduleIndex,
                          modules: state.modules,
                        ),
                      ),

                      _OverviewSubSection(
                        title: 'Time Breakdown',
                        color: AppColors.neon2,
                        children: [
                          _TimeBar('Theory & Concepts', (m.hours * 0.3).round(),
                              m.hours, AppColors.neon),
                          _TimeBar('Guided Examples', (m.hours * 0.3).round(),
                              m.hours, AppColors.neon2),
                          _TimeBar('Practice Tasks', (m.hours * 0.4).round(),
                              m.hours, AppColors.neon3),
                        ],
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Practice Tasks (Checkboxes) ────────────────
              if (m.practice.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'PRACTICE TASKS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.txt3,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = m.practice[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.s1,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.s3),
                          ),
                          child: CheckboxListTile(
                            value: taskChecked[index],
                            onChanged: isLocked ? null : (val) => state.setModuleTask(m.id, index, val ?? false),
                            activeColor: AppColors.neon,
                            checkColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text(
                              task,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: taskChecked[index] ? AppColors.txt4 : AppColors.txt2,
                                decoration: taskChecked[index] ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: m.practice.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              // ── Resources (Link Cards) ────────────────────
              if (m.resources.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'LEARNING RESOURCES',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.txt3,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final r = m.resources[index];
                        // FIX: Use buildResourceUrl() instead of r['url'] directly.
                        // AI-generated URLs were unreliable (hallucinated or "google.com").
                        // buildResourceUrl() constructs a guaranteed working search URL
                        // from the platform + search_query fields the AI now provides.
                        final url = r.containsKey('platform')
                            ? AiService.buildResourceUrl(r)
                            : (r['url'] as String? ?? '');
                        final platformDisplay = r.containsKey('platform')
                            ? AiService.platformLabel(r)
                            : _inferPlatform(r['url'] as String? ?? '');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.s1,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.s3),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.neon2.withOpacity(0.12),
                                border: Border.all(
                                    color: AppColors.neon2
                                        .withOpacity(0.25)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _platformIcon(r['platform'] as String? ?? ''),
                                color: AppColors.neon2,
                                size: 16,
                              ),
                            ),
                            title: Text(
                              r['title'] as String? ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.txt,
                              ),
                            ),
                            subtitle: Text(
                              platformDisplay,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: AppColors.neon2),
                            ),
                            trailing: Icon(Icons.open_in_new_rounded,
                                color: AppColors.neon2, size: 14),
                            onTap: () => _launchURL(url),
                          ),
                        );
                      },
                      childCount: m.resources.length,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ── Pinned Bottom Button ──────────────────────────────
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (isActive && !_completing)
                    BoxShadow(color: AppColors.neon.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))
                ],
              ),
              child: ElevatedButton(
                onPressed: (isActive && !_completing)
                    ? () async {
                        setState(() => _completing = true);
                        await context.read<AppState>().completeModule(m.id);
                        if (mounted) {
                          setState(() => _completing = false);
                          showToast(context, 'Module Complete!');
                          Navigator.pop(context);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: AppColors.s3.withOpacity(0.5),
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.disabled)) return AppColors.s3.withOpacity(0.5);
                    if (isDone) return Colors.blueGrey.withOpacity(0.2);
                    return null; // Gradient will show
                  }),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: (isActive && !_completing) ? AppColors.grad1 : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_completing)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        else
                          Icon(
                            isDone ? Icons.check_circle : isActive ? Icons.stars_rounded : Icons.lock_outline_rounded,
                            color: isDone ? AppColors.txt4 : Colors.white,
                          ),
                        const SizedBox(width: 12),
                        Text(
                          _completing
                              ? 'SAVING...'
                              : isDone
                                  ? 'COMPLETED'
                                  : isActive
                                      ? 'MARK COMPLETE'
                                      : 'COMPLETE PREVIOUS MODULE FIRST',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDone ? AppColors.txt4 : Colors.white,
                            letterSpacing: 0.5,
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
// ── Helpers ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.s1,
            border: Border.all(color: AppColors.s3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.txt3)),
          ]),
        ),
      );
}

class _OverviewSubSection extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;
  const _OverviewSubSection({
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: Border.all(color: color.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.08)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final Color color;
  const _BulletPoint({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 6, right: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.txt3, height: 1.5),
              ),
            ),
          ],
        ),
      );
}

class _TimeBar extends StatelessWidget {
  final String label;
  final int hours, totalHours;
  final Color color;
  const _TimeBar(this.label, this.hours, this.totalHours, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: AppColors.txt3)),
            Text('${hours}h',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ]),
          const SizedBox(height: 4),
          Container(
            height: 3,
            decoration: BoxDecoration(
                color: AppColors.s3, borderRadius: BorderRadius.circular(100)),
            child: FractionallySizedBox(
              widthFactor: (hours / totalHours).clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(100)),
              ),
            ),
          ),
        ]),
      );
}

class _PrereqRow extends StatelessWidget {
  final String text;
  final bool met;
  const _PrereqRow({required this.text, required this.met});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: met
                  ? AppColors.neon3.withOpacity(0.15)
                  : AppColors.gold.withOpacity(0.15),
              border: Border.all(
                  color: met
                      ? AppColors.neon3.withOpacity(0.6)
                      : AppColors.gold.withOpacity(0.6)),
            ),
            child: Icon(
              met ? Icons.check_rounded : Icons.lock_outline_rounded,
              size: 9,
              color: met ? AppColors.neon3 : AppColors.gold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.txt3))),
        ]),
      );
}

// ── Resource helpers ──────────────────────────────────────────
IconData _platformIcon(String platform) => switch (platform.toLowerCase()) {
      'youtube'      => Icons.play_circle_outline_rounded,
      'freecodecamp' => Icons.code_rounded,
      'pub_dev'      => Icons.widgets_outlined,
      'github'       => Icons.source_rounded,
      'mdn'          => Icons.description_outlined,
      'dev_to'       => Icons.article_outlined,
      'official_docs'=> Icons.menu_book_outlined,
      _              => Icons.play_circle_outline_rounded,
    };

String _inferPlatform(String url) {
  if (url.contains('youtube')) return 'YouTube';
  if (url.contains('freecodecamp')) return 'freeCodeCamp';
  if (url.contains('pub.dev')) return 'pub.dev';
  if (url.contains('github')) return 'GitHub';
  if (url.contains('developer.mozilla')) return 'MDN Docs';
  if (url.contains('dev.to')) return 'dev.to';
  return 'Resource';
}