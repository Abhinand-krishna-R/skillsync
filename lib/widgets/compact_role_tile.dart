import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/roles_db.dart';
import '../services/scoring_service.dart';
import '../theme/app_theme.dart';
import '../screens/role_detail_screen.dart';
import 'common.dart';

class CompactRoleTile extends StatelessWidget {
  final String slug;
  final int pct;
  final bool isTarget;

  const CompactRoleTile({
    super.key,
    required this.slug,
    required this.pct,
    this.isTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    
    // Fallback for AI-generated dynamic roles not in local RolesDB
    final role = RolesDB.safeGet(slug) ?? state.getDynamicRole(slug) ?? CareerRole(
      slug: slug,
      name: slug.replaceAll('_', ' ').replaceAll('-', ' ').split(' ')
                 .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' '),
      description: 'AI Suggested Role',
      category: 'Dynamic',
      demand: 'High',
      salary: '',
      icon: 'auto_awesome',
      color: AppColors.neon2,
      requiredSkills: const [],
      weights: const {},
      requiredLevels: const {},
      tools: const [],
      aiTips: const [],
      qualificationRequired: false,
      qualifications: const [],
      qualificationNote: '',
    );
    
    final c = role.color;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoleDetailScreen(slug: slug))),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isTarget ? AppColors.neon.withAlpha(20) : AppColors.s1, // 0.08 * 255 = 20
          border: Border.all(color: isTarget ? AppColors.neon : AppColors.s3),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isTarget ? [BoxShadow(color: AppColors.neon.withAlpha(51), blurRadius: 20)] : null, // 0.2 * 255 = 51
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.withAlpha(25), // 0.1 * 255 = 25
                border: Border.all(color: c.withAlpha(51)), // 0.2 * 255 = 51
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(roleIcon(role.icon), color: c, size: 18),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          role.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.txt,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$pct%', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 20, color: c)),
                    ],
                  ),
                  Text(
                    '${role.category} · ${role.demand} demand',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.txt3,
                      letterSpacing: 0.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Missing skills hint
                  Builder(
                    builder: (ctx) {
                      final gaps = ScoringService.analyzeGap(state.skills, role);
                      final missing = gaps['missing'] ?? [];
                      if (missing.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Missing: ${missing.take(2).join(", ")}${missing.length > 2 ? "..." : ""}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.hot.withAlpha(204), // 0.8 * 255 = 204
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Progress bar
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.s3,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: pct / 100,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [BoxShadow(color: c.withAlpha(153), blurRadius: 6)], // 0.6 * 255 = 153
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
