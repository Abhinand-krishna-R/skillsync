import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/ui_state.dart';
import '../models/roles_db.dart';
import '../services/scoring_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'role_detail_screen.dart';
import '../widgets/compact_role_tile.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _searchResult;
  bool _searching = false;
  String? _searchError;

  static const _popular = [
    'Flutter Developer', 'UX Designer', 'Data Scientist',
    'Product Manager', 'DevOps Engineer', 'AI Engineer',
    'Cybersecurity Analyst', 'Backend Developer',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _searchResult = null;
    });

    try {
      final result =
          await context.read<AppState>().searchRole(query.trim());
      if (mounted) {
        setState(() {
          _searchResult = result;
          if (result == null) {
            _searchError = 'AI could not generate role. Please try again.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Search failed. Please try again.';
        final errStr = e.toString();
        if (errStr.contains('key is missing')) {
          msg = 'AI Key missing. Please check your configuration.';
        } else if (errStr.contains('401')) {
          msg = 'AI Authentication failed. Please check your API key.';
        } else if (errStr.contains('timeout')) {
          msg = 'Search timed out. Check your connection.';
        }
        setState(() => _searchError = msg);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ui = context.watch<UiState>();
    return Column(children: [
      const SkillTopBar('Career Explorer'),
      AppTabs(
        tabs: const ['My Matches', 'Search Roles'],
        current: ui.rolesTab.index,
        onChanged: (t) => context.read<UiState>().setRolesTab(RolesTab.values[t]),
      ),
      Expanded(
        child: ui.rolesTab == RolesTab.matches
            ? _buildMatches(state, ui)
            : _buildSearch(state, ui),
      ),
    ]);
  }

  Widget _buildMatches(AppState state, UiState ui) {
    if (state.skills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.explore_outlined,
                size: 40, color: AppColors.txt3),
            const SizedBox(height: 16),
            Text('No matches yet',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.txt)),
            const SizedBox(height: 8),
            Text('Add skills to discover matching careers',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.txt3)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                ui.setTab(AppTab.analyze);
                WidgetsBinding.instance.addPostFrameCallback((_) => ui.setAnalyzeTab(AnalyzeTab.resume));
              },
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
                  Text('ANALYSE MY RESUME',
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

    // Local role matching — fast, no AI
    final scores = state.roleMatches;
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final targetSlug = state.profile?.targetRoleSlug;
    // Derive bestSlug from the FULL roleMatches map (includes dynamic AI roles)
    // so the 'Best' chip always reflects the highest actual score, not just
    // the highest-scoring static role.
    final bestSlug = (scores.isNotEmpty && targetSlug == null)
        ? scores.entries.reduce((a, b) => a.value.score > b.value.score ? a : b).key
        : null;

    return ListView(
      key: const PageStorageKey('explore_matches_list'),
      padding: const EdgeInsets.all(16), 
      children: [
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding:
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: AppColors.neon.withValues(alpha: 0.06),
            border: Border.all(color: AppColors.neon.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.neon, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: 'Scores show your skill match % vs each role',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.txt3)),
                if (targetSlug != null)
                  TextSpan(
                      text:
                          ' · ${state.profile?.targetRoleLabel} is your target',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.neon3,
                          fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
      ...sorted.take(10).map((e) => CompactRoleTile(
            slug: e.key,
            pct: e.value.score,
            isTarget: e.key == targetSlug,
          )),

      // ── Similar Roles Section ──
      if (sorted.length > 10) ...[
        const SizedBox(height: 24),
        SectionHeader('Similar Roles'),
        const SizedBox(height: 10),
        ..._buildSimilarRoles(state, sorted, targetSlug ?? bestSlug),
      ],
    ]);
  }

  List<Widget> _buildSimilarRoles(AppState state, List<MapEntry<String, MatchResult>> sorted, String? referenceSlug) {
    if (referenceSlug == null) return [];
    
    final refRole = RolesDB.safeGet(referenceSlug) ?? state.getDynamicRole(referenceSlug);
    if (refRole == null) return [];
    
    final cluster = refRole.careerCluster;
    
    // Find roles in the same cluster that aren't in the top matches already shown
    final similar = sorted.skip(10).where((e) {
      final role = RolesDB.safeGet(e.key) ?? state.getDynamicRole(e.key);
      return role?.careerCluster == cluster;
    }).take(4).toList();

    if (similar.isEmpty) return [];

    return similar.map((e) => CompactRoleTile(
      slug: e.key,
      pct: e.value.score,
    )).toList();
  }

  Widget _buildSearch(AppState state, UiState ui) =>
      ListView(key: const PageStorageKey('explore_search_list'), padding: const EdgeInsets.all(16), children: [
        // Search bar
        Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: AppColors.s2,
                  border: Border.all(color: AppColors.s3),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Padding(
                    padding: EdgeInsets.only(left: 13),
                    child: Icon(Icons.search_rounded,
                        color: AppColors.txt3, size: 17)),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: AppColors.txt),
                    decoration: InputDecoration(
                      hintText: 'Search any role…',
                      hintStyle: GoogleFonts.plusJakartaSans(
                          color: AppColors.txt3, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 14),
                    ),
                    onSubmitted: _runSearch,
                    textInputAction: TextInputAction.search,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _runSearch(_searchCtrl.text),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.grad1,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.neon.withValues(alpha: 0.4),
                      blurRadius: 16)
                ],
              ),
              child: _searching
                  ? const Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 21),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        // Error
        if (_searchError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.hot.withValues(alpha: 0.08),
                border:
                    Border.all(color: AppColors.hot.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.hot, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_searchError!,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppColors.hot))),
            ]),
          ),

        // Search result
        if (_searchResult != null)
          _SearchResultCard(
            roleData: _searchResult!,
            onSetTarget: (slug, label) async {
              try {
                await context.read<AppState>().setTargetRole(slug, label);
                if (context.mounted) {
                  showToast(context, '$label set as target role!');
                  context.read<UiState>().setTab(AppTab.roadmap); // go to roadmap
                }
              } catch (e) {
                if (context.mounted) {
                  showToast(context, 'Failed to generate roadmap: $e', warn: true);
                }
              }
            },
          ),

        // Popular searches
        SectionHeader('Popular Searches'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _popular
              .map((r) => GestureDetector(
                    onTap: () {
                      _searchCtrl.text = r;
                      _runSearch(r);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppColors.s2,
                          border: Border.all(color: AppColors.s4),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(r,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.txt3,
                              letterSpacing: 0.04)),
                    ),
                  ))
              .toList(),
        ),
      ]);
}


// ── Search Result Card (Search Roles tab) ─────────────────────
class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> roleData;
  final Future<void> Function(String slug, String label) onSetTarget;
  const _SearchResultCard(
      {required this.roleData, required this.onSetTarget});

  @override
  Widget build(BuildContext context) {
    final title = roleData['title'] as String? ??
        roleData['name'] as String? ?? 'Unknown Role';
    final description = roleData['description'] as String? ?? '';
    final salary = roleData['salary'] as String? ??
        roleData['salaryRange'] as String? ?? '₹4–20 LPA';
    final demand = roleData['demand'] as String? ?? 'High';
    final slug = roleData['slug'] as String? ?? RolesDB.slugify(title);
    final skills = List<String>.from(
        roleData['requiredSkills'] as List? ?? roleData['skills'] as List? ?? []);
    final source = roleData['source'] as String? ?? 'ai';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.s1,
          border: Border.all(color: AppColors.neon.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                gradient: AppColors.grad1,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.work_outline_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.txt)),
              Row(children: [
                SkillChip(
                    source == 'local' ? 'In library' : 'Career Database',
                    variant: source == 'local'
                        ? ChipVariant.green
                        : ChipVariant.cyan),
              ]),
            ]),
          ),
        ]),

        // Description
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(description,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.txt3, height: 1.65)),
        ],

        // Salary + Demand
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                  color: AppColors.s2,
                  border: Border.all(color: AppColors.s3),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text('INDIA SALARY',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.txt3,
                        letterSpacing: 0.06)),
                const SizedBox(height: 3),
                Text(salary,
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.neon3)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                  color: AppColors.s2,
                  border: Border.all(color: AppColors.s3),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text('DEMAND',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.txt3,
                        letterSpacing: 0.06)),
                const SizedBox(height: 3),
                Text(demand,
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.neon2)),
              ]),
            ),
          ),
        ]),

        // Required skills preview
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('REQUIRED SKILLS',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.txt3,
                  letterSpacing: 0.08)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                skills.take(5).map((s) => SkillChip(s)).toList(),
          ),
        ],

        const SizedBox(height: 14),

        // Action buttons
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppColors.s1, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.neon),
                          const SizedBox(height: 16),
                          Text('Generating roadmap...', style: GoogleFonts.plusJakartaSans(color: AppColors.txt, fontSize: 13, decoration: TextDecoration.none)),
                        ],
                      ),
                    ),
                  ),
                );
                try {
                  await onSetTarget(slug, title);
                } catch (e) {
                  if (context.mounted) showToast(context, 'Error: $e', warn: true);
                } finally {
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                    gradient: AppColors.grad1,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.neon.withValues(alpha: 0.3),
                          blurRadius: 12)
                    ]),
                child: Center(
                  child: Text('SET AS TARGET',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.04)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RoleDetailScreen(slug: slug, roleData: roleData))),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.s4),
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: Text('DETAILS',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.txt3,
                          letterSpacing: 0.04)),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
