import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/skill_model.dart';
import '../models/ui_state.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AnalyzeScreen extends StatelessWidget {
  const AnalyzeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiState>();
    return Column(children: [
      const SkillTopBar('Skill Analyzer'),
      AppTabs(
        tabs: const ['Overview', 'Resume', 'Manual'],
        current: ui.analyzeTab.index,
        onChanged: (t) => context.read<UiState>().setAnalyzeTab(AnalyzeTab.values[t]),
      ),
      Expanded(
        child: [
          const _OverviewTab(),
          const _ResumeTab(),
          const _ManualTab(),
        ][ui.analyzeTab.index],
      ),
    ]);
  }
}

// ── Overview Tab ───────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.skills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.science_outlined, size: 40, color: AppColors.txt3),
            const SizedBox(height: 16),
            Text('No skills yet',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.txt)),
            const SizedBox(height: 8),
            Text(
                'Upload your resume or add skills manually to see your full analysis',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.txt3)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.read<UiState>().setAnalyzeTab(AnalyzeTab.resume),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                    gradient: AppColors.grad1,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.description_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('UPLOAD RESUME',
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

    final gap = state.gapAnalysis;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Center(child: ScoreRing(score: state.score, size: 168, strokeWidth: 11)),
          const SizedBox(height: 16),
          Row(children: [
            _StatBox('${gap['matched']?.length ?? 0}', 'Matching',
                AppColors.neon3, Icons.check_circle_outline_rounded),
            const SizedBox(width: 8),
            _StatBox('${gap['weak']?.length ?? 0}', 'Needs Work',
                AppColors.gold, Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            _StatBox('${gap['missing']?.length ?? 0}', 'Missing',
                AppColors.hot, Icons.close_rounded),
          ]),
          const SizedBox(height: 16),
          if (gap['matched']?.isNotEmpty ?? false)
            _SkillGroup(
                'Matched Skills',
                state.skills
                    .where((s) => gap['matched']!
                        .any((m) => m.toLowerCase() == s.name.toLowerCase()))
                    .toList(),
                AppColors.neon3,
                ChipVariant.green),
          if (gap['weak']?.isNotEmpty ?? false)
            _SkillGroup(
                'Needs Work',
                state.skills
                    .where((s) => gap['weak']!
                        .any((m) => m.toLowerCase() == s.name.toLowerCase()))
                    .toList(),
                AppColors.gold,
                ChipVariant.amber),
          
          if (gap['missing']?.isNotEmpty ?? false)
            _GapInsights(missing: gap['missing']!),

          const SizedBox(height: 16),
          Text('ALL SKILLS',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.txt3,
                  letterSpacing: 0.12)),
          const SizedBox(height: 10),
          ...state.skills.map((s) => _DismissibleSkill(
                skill: s,
                onDelete: () => state.deleteSkill(s.id),
              )),
        ]);
  }
}

class _DismissibleSkill extends StatelessWidget {
  final SkillModel skill;
  final VoidCallback onDelete;
  const _DismissibleSkill({required this.skill, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(skill.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (dir) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.s2,
                title: Text('Remove Skill?', style: AppText.grotesk(sz: 18)),
                content: Text('Remove "${skill.name}" from your profile?',
                    style: AppText.jakarta(c: AppColors.txt2)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('CANCEL', style: AppText.jakarta(c: AppColors.txt3))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('DELETE', style: AppText.jakarta(c: AppColors.hot))),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        onDelete();
        showToast(context, '"${skill.name}" removed');
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(204), // 0.8 * 255 = 204
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => _showEditSkillSheet(context, skill),
        child: SkillBar(name: skill.name, level: skill.level, sublabel: skill.label),
      ),
    );
  }

  void _showEditSkillSheet(BuildContext context, SkillModel skill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSkillSheet(skill: skill),
    );
  }
}

class _EditSkillSheet extends StatefulWidget {
  final SkillModel skill;
  const _EditSkillSheet({required this.skill});
  @override
  State<_EditSkillSheet> createState() => _EditSkillSheetState();
}

class _EditSkillSheetState extends State<_EditSkillSheet> {
  late double _level;
  late String _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _level = widget.skill.level.toDouble();
    _category = widget.skill.category;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: AppColors.s2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Edit Skill', style: AppText.grotesk(sz: 20, w: FontWeight.w700)),
          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 12),
        Text(widget.skill.name, 
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.jakarta(sz: 16, w: FontWeight.w600, c: AppColors.neon)),
        const SizedBox(height: 24),
        
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Proficiency Level', style: AppText.jakarta(sz: 13, w: FontWeight.w600, c: AppColors.txt3)),
          Text(_level.round().toString(), style: AppText.grotesk(sz: 24, w: FontWeight.w900, c: AppColors.scoreColor(_level.round()))),
        ]),
        SliderTheme(
          data: SliderThemeData(
            thumbColor: AppColors.neon,
            activeTrackColor: AppColors.neon,
            inactiveTrackColor: AppColors.s3,
          ),
          child: Slider(
            value: _level,
            min: 1, max: 100,
            onChanged: (v) => setState(() => _level = v),
          ),
        ),
        const SizedBox(height: 20),
        
        Text('Category', style: AppText.jakarta(sz: 13, w: FontWeight.w600, c: AppColors.txt3)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          'Frontend', 'Backend', 'Design', 'Mobile', 'Soft Skills', 'Other'
        ].map((c) => GestureDetector(
          onTap: () => setState(() => _category = c),
          child: Chip(
            label: Text(c, style: TextStyle(fontSize: 12, color: _category == c ? Colors.white : AppColors.txt)),
            backgroundColor: _category == c ? AppColors.neon : AppColors.s1,
            side: BorderSide(color: _category == c ? AppColors.neon : AppColors.s3),
          ),
        )).toList()),
        
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
          onPressed: _saving ? null : () async {
            setState(() => _saving = true);
            try {
              await state.updateSkill(
                skillId: widget.skill.id,
                level: _level.round(),
                category: _category,
              );
              if (mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _saving = false);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neon,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving 
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('SAVE CHANGES', style: AppText.jakarta(sz: 14, w: FontWeight.w700, c: Colors.white)),
        )),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatBox(this.value, this.label, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: color.withAlpha(20), // 0.08 * 255 = 20.4 -> 20
              border: Border.all(color: color.withAlpha(64)), // 0.25 * 255 = 63.75 -> 64
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800, fontSize: 22, color: color)),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.txt3)),
          ]),
        ),
      );
}

class _SkillGroup extends StatelessWidget {
  final String title;
  final List<SkillModel> skills;
  final Color color;
  final ChipVariant variant;
  const _SkillGroup(this.title, this.skills, this.color, this.variant);
  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withAlpha(204), // 0.8 * 255 = 204
              letterSpacing: 0.12)),
      const SizedBox(height: 8),
      Wrap(
          spacing: 6,
          runSpacing: 6,
          children:
              skills.map((s) => SkillChip(s.name, variant: variant)).toList()),
      const SizedBox(height: 16),
    ]);
  }
}

class _GapInsights extends StatelessWidget {
  final List<String> missing;
  const _GapInsights({required this.missing});
  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.s2,
          border: Border.all(color: AppColors.s3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.rocket_launch_outlined, color: AppColors.neon, size: 18),
            const SizedBox(width: 8),
            Text('NEXT STEPS: FILL THE GAPS',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neon,
                    letterSpacing: 0.12)),
          ]),
          const SizedBox(height: 12),
          Text('To reach the next level in your target role, focus on these missing skills:',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.txt2, height: 1.4)),
          const SizedBox(height: 12),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing
                  .take(8)
                  .map((s) => SkillChip(s, variant: ChipVariant.red))
                  .toList()),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.read<UiState>().setTab(AppTab.roadmap), // Go to Roadmap tab
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.neon.withAlpha(25), // 0.1 * 255 = 25.5 -> 25
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('GENERATE ROADMAP',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neon)),
              ),
            ),
          ),
        ]),
      );
}

// ── Resume Tab ─────────────────────────────────────────────────
class _ResumeTab extends StatelessWidget {
  const _ResumeTab();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ui = context.watch<UiState>();
    final rs = ui.resumeState;

    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 90),
        children: [
          if (rs == ResumeState.uploading || rs == ResumeState.parsing) ...[
            _LoadingState(
              label: ui.resumeProgress,
              fraction: ui.resumeProgressFraction,
            ),
          ] else if (rs == ResumeState.done) ...[
            _DoneState(skills: state.skills),
            const SizedBox(height: 16),
            if (ui.pendingUnverifiedSkills.isNotEmpty)
              _UnverifiedSkillsCard(skills: ui.pendingUnverifiedSkills),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.read<UiState>().resetResumeState(),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.s4),
                    borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text('UPLOAD ANOTHER RESUME',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.txt3,
                          letterSpacing: 0.04)),
                ),
              ),
            ),
          ] else ...[
            if (rs == ResumeState.error)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.hot.withAlpha(25), // 0.1 * 255 = 25.5 -> 25
                    border: Border.all(color: AppColors.hot.withAlpha(76)), // 0.3 * 255 = 76.5 -> 76
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppColors.hot, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(ui.resumeError ?? 'Upload failed',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: AppColors.hot)),
                  ),
                ]),
              ),
            _UploadZone(
              onTap: () async {
                await context
                    .read<UiState>()
                    .uploadResume(context.read<AppState>());
              },
            ),
            const SizedBox(height: 32),
            const _AnalysisFeatures(),
            const SizedBox(height: 48),
            const _UploadTip(),
          ],
        ]);
  }
}

// ── Analysis Features Section ──────────────────────────────────
class _AnalysisFeatures extends StatelessWidget {
  const _AnalysisFeatures();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What we\'ll analyze',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.txt,
          ),
        ),
        const SizedBox(height: 16),
        _FeatureItem('Technical skills'),
        _FeatureItem('Experience level'),
        _FeatureItem('Missing skills'),
        _FeatureItem('Career roadmap'),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String label;
  const _FeatureItem(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.check_rounded, color: AppColors.neon, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.txt2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upload Tip Footer ──────────────────────────────────────────
class _UploadTip extends StatelessWidget {
  const _UploadTip();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Tip: Upload your latest resume for the most accurate skill analysis.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.txt3,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _UploadZone extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadZone({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
              color: AppColors.s2,
              border: Border.all(
                color: AppColors.neon.withAlpha(38), // 0.15 * 255 = 38.25 -> 38
              ),
              borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.neon.withAlpha(25), // 0.1 * 255 = 25.5 -> 25
                  shape: BoxShape.circle),
              child: Icon(Icons.cloud_upload_outlined,
                  color: AppColors.neon, size: 36),
            ),
            const SizedBox(height: 24),
            Text('Upload Your Resume',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: AppColors.txt,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                  'AI will scan your resume and extract your skills automatically.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: AppColors.txt3, height: 1.5)),
            ),
            const SizedBox(height: 32),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                  gradient: AppColors.grad1,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.neon.withAlpha(76), // 0.3 * 255 = 76.5 -> 76
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('CHOOSE FILE',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5)),
              ]),
            ),
            const SizedBox(height: 20),
            Text('PDF · TXT · Max 5MB',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.txt3)),
          ]),
        ),
      );
}

// [DELETE] _WhatWeExtract widget removed per Issue 7

class _LoadingState extends StatelessWidget {
  final String label;
  final double fraction;
  const _LoadingState({required this.label, required this.fraction});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: AppColors.s1,
            border: Border.all(color: AppColors.s3),
            borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                gradient: AppColors.grad1,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.neon.withAlpha(102), blurRadius: 20) // 0.4 * 255 = 102
                ]),
            child: const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          Text(label.isEmpty ? 'Processing…' : label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.txt),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppColors.s3,
              minHeight: 4,
              valueColor: AlwaysStoppedAnimation(AppColors.neon),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(fraction * 100).round()}%',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neon)),
        ]),
      );
}

class _DoneState extends StatelessWidget {
  final List<SkillModel> skills;
  const _DoneState({required this.skills});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: AppColors.neon3.withAlpha(20), // 0.08 * 255 = 20.4 -> 20
              border:
                  Border.all(color: AppColors.neon3.withAlpha(76)), // 0.3 * 255 = 76.5 -> 76
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.neon3, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${skills.length} skills detected from your resume',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.txt)),
                    Text('AI mapped your career profile',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: AppColors.txt3)),
                  ]),
            ),
          ]),
        ),
        ...skills.map((s) =>
            SkillBar(name: s.name, level: s.level, sublabel: s.label)),
      ]);
}

// ── Manual Tab — Redesigned ─────────────────────────────────────
class _ManualTab extends StatefulWidget {
  const _ManualTab();
  @override
  State<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends State<_ManualTab> {
  final _nameCtrl = TextEditingController();
  double _level = 65;
  String _category = 'Other';
  bool _loadingCategory = false;
  bool _saving = false;

  // Skill queue — user adds multiple before saving all at once
  final List<Map<String, dynamic>> _queue = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Fetch AI-suggested category when user finishes typing
  Future<void> _onSkillNameSubmitted(String value) async {
    if (value.trim().isEmpty) return;
    setState(() => _loadingCategory = true);
    final suggested = await AiService.suggestSkillCategory(value.trim());
    if (mounted) {
      setState(() {
        _category = suggested;
        _loadingCategory = false;
      });
    }
  }

  void _addToQueue() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showToast(context, 'Enter a skill name', warn: true);
      return;
    }
    // Check for duplicates in current queue
    if (_queue.any((s) =>
        (s['name'] as String).toLowerCase() == name.toLowerCase())) {
      showToast(context, '"$name" already in queue', warn: true);
      return;
    }
    // Check for duplicates against already-saved skills (cross-session guard)
    final state = context.read<AppState>();
    if (state.skills.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      showToast(context, '"$name" already in your skills', warn: true);
      return;
    }
    setState(() {
      _queue.add({
        'name': name,
        'level': _level.round(),
        'category': _category,
      });
      _nameCtrl.clear();
      _level = 65;
      _category = 'Other';
    });
  }

  Future<void> _saveAll() async {
    if (_queue.isEmpty) {
      showToast(context, 'Add at least one skill', warn: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().addSkillsBatch(_queue);
      if (mounted) {
        showToast(context, '${_queue.length} skills saved!');
        setState(() {
          _queue.clear();
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Failed to save skills', warn: true);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 90),
        children: [
          // ── Header ─────────────────────────────────────────────
          Text('Add Skills',
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.txt,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Add a skill to analyze your career readiness',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.txt3)),
          const SizedBox(height: 20),

          // ── Skill Name Field ────────────────────────────────────
          Container(
            decoration: BoxDecoration(
                color: AppColors.s2,
                border: Border.all(color: AppColors.s3),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Icon(Icons.star_outline_rounded,
                      color: AppColors.txt3, size: 17)),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: AppColors.txt),
                  decoration: InputDecoration(
                    hintText: 'Flutter, React, Python...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        color: AppColors.txt3),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  onSubmitted: _onSkillNameSubmitted,
                  onEditingComplete: () =>
                      _onSkillNameSubmitted(_nameCtrl.text),
                  textInputAction: TextInputAction.done,
                ),
              ),
              // AI category badge
              if (_loadingCategory)
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.neon)),
                )
              else if (_category != 'Other')
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SkillChip(_category, variant: ChipVariant.cyan),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Level Slider ────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Proficiency Level',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.txt3)),
            Text(
              '${_level.round()} • ${_level.round() >= 80 ? 'Advanced' : _level.round() >= 55 ? 'Intermediate' : 'Beginner'}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.scoreColor(_level.round())),
            ),
          ]),
          SliderTheme(
            data: SliderThemeData(
              thumbColor: AppColors.neon,
              activeTrackColor: AppColors.neon,
              inactiveTrackColor: AppColors.s3,
              overlayColor: AppColors.neon.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _level,
              min: 1,
              max: 100,
              onChanged: (v) => setState(() => _level = v),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Beginner',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: AppColors.txt3)),
            Text('Expert',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: AppColors.txt3)),
          ]),
          const SizedBox(height: 16),

          // ── Add to Queue Button ────────────────────────────────
          GestureDetector(
            onTap: _addToQueue,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neon),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_rounded, color: AppColors.neon, size: 18),
                const SizedBox(width: 8),
                Text('Add Skill',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neon,
                        letterSpacing: 0.04)),
              ]),
            ),
          ),

          // ── Skill Queue ─────────────────────────────────────────
          if (_queue.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('READY TO SAVE (${_queue.length})',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.txt3,
                      letterSpacing: 0.12)),
              GestureDetector(
                onTap: () => setState(() => _queue.clear()),
                child: Text('Clear all',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.hot)),
              ),
            ]),
            const SizedBox(height: 10),
            ..._queue.map((skill) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppColors.s1,
                      border: Border.all(color: AppColors.neon.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(skill['name'] as String,
                              style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.txt)),
                          Text(
                              '${skill['category']} · Level ${skill['level']}',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: AppColors.txt3)),
                        ])),
                    GestureDetector(
                      onTap: () => setState(() => _queue.remove(skill)),
                      child: Icon(Icons.close_rounded,
                          color: AppColors.txt3, size: 16),
                    ),
                  ]),
                )),
            const SizedBox(height: 12),

            // ── Save All Button ─────────────────────────────────
            GestureDetector(
              onTap: _saving ? null : _saveAll,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 52,
                decoration: BoxDecoration(
                  gradient: _saving ? null : AppColors.grad1,
                  color: _saving ? AppColors.s3 : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _saving
                      ? null
                      : [
                          BoxShadow(
                              color: AppColors.neon.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4))
                        ],
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_saving)
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.save_rounded,
                            color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                          _saving
                              ? 'SAVING…'
                              : 'SAVE ${_queue.length} SKILL${_queue.length > 1 ? 'S' : ''}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _saving ? AppColors.txt3 : Colors.white,
                              letterSpacing: 0.04)),
                    ]),
              ),
            ),
          ],

          // ── Existing Skills ────────────────────────────────────
          if (state.skills.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(children: [
              Text('Your Skills (${state.skills.length})',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.txt3,
                      letterSpacing: 0.12)),
              const SizedBox(width: 8),
              Text('Swipe left to delete',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                  )),
            ]),
            const SizedBox(height: 10),
            ...state.skills.map((s) => _DismissibleSkill(
                  skill: s,
                  onDelete: () => context.read<AppState>().deleteSkill(s.id),
                )),
          ],
        ]);
  }
}

class _UnverifiedSkillsCard extends StatefulWidget {
  final List<Map<String, dynamic>> skills;
  const _UnverifiedSkillsCard({required this.skills});

  @override
  State<_UnverifiedSkillsCard> createState() => _UnverifiedSkillsCardState();
}

class _UnverifiedSkillsCardState extends State<_UnverifiedSkillsCard> {
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.generate(widget.skills.length, (_) => true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.skills.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.s1,
        border: Border.all(color: AppColors.s3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  color: AppColors.gold, size: 20),
              const SizedBox(width: 10),
              Text('Unverified Skills',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.txt)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'These skills were found but need verification. Select the ones you want to add.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.txt3)),
          const SizedBox(height: 16),
          ...List.generate(widget.skills.length, (i) {
            final s = widget.skills[i];
            return CheckboxListTile(
              value: _selected[i],
              onChanged: (val) => setState(() => _selected[i] = val ?? false),
              title: Text(s['name'] ?? '',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.txt)),
              subtitle: Text(s['category'] ?? 'General',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppColors.txt3)),
              dense: true,
              activeColor: AppColors.neon,
              checkColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              final confirmed = <Map<String, dynamic>>[];
              for (int i = 0; i < widget.skills.length; i++) {
                if (_selected[i]) confirmed.add(widget.skills[i]);
              }
              context.read<UiState>().confirmUnverifiedSkills(
                    context.read<AppState>(),
                    confirmed,
                  );
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.grad1,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text('VERIFY & ADD SELECTED',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
