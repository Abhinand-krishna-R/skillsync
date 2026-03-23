import '../models/skill_model.dart';
import '../models/roles_db.dart';

/// Result of a role match calculation.
class MatchResult {
  final String slug;
  final int score;
  final List<String> matchedSkills;
  final List<String> weakSkills;
  final List<String> missingSkills;

  MatchResult({
    required this.slug,
    required this.score,
    required this.matchedSkills,
    required this.weakSkills,
    required this.missingSkills,
  });

  int compareTo(MatchResult other) => score.compareTo(other.score);
}

/// Decoupled scoring logic for SkillSync.
/// Implements a balanced F1-style formula to prevent score inflation.
class ScoringService {
  /// Calculates a balanced match score (0-100).
  /// Formula: score = (2 * matched) / (required + min(userTotal, required * 2))
  /// Then adjusted for skill levels, weights, and role difficulty.
  static MatchResult computeMatch(List<SkillModel> userSkills, CareerRole role) {
    if (role.requiredSkills.isEmpty) {
      return MatchResult(slug: role.slug, score: 0, matchedSkills: [], weakSkills: [], missingSkills: []);
    }

    final gaps = analyzeGap(userSkills, role);
    final matchedCount = gaps['matched']!.length;
    final weakCount = gaps['weak']!.length;
    final totalMatched = matchedCount + (weakCount * 0.5); // Weak matches count as half

    final r = role.requiredSkills.length.toDouble();
    final u = userSkills.length.toDouble();
    
    // 1. Base F1 Score (Capped)
    // Formula: 2 * matched / (r + min(u, r * 2))
    final uCapped = u.clamp(0.0, r * 2);
    double baseF1 = (2 * totalMatched) / (r + uCapped);

    // 2. Proficiency Adjustment (Weights & Levels)
    double earnedWeightedScore = 0;
    double totalPossibleWeightedScore = 0;

    for (final req in role.requiredSkills) {
      final weight = role.weights[req] ?? 1.0;
      final requiredLevel = (role.requiredLevels[req] ?? 80).toDouble();
      totalPossibleWeightedScore += requiredLevel * weight;

      final sk = userSkills.where((s) => RolesDB.isMatch(s.name, req)).firstOrNull;
      if (sk != null) {
        final effectiveLevel = sk.level.toDouble().clamp(0.0, requiredLevel);
        earnedWeightedScore += effectiveLevel * weight;
      }
    }

    final proficiencyFactor = totalPossibleWeightedScore > 0 
        ? (earnedWeightedScore / totalPossibleWeightedScore) 
        : 0.0;

    // 3. Final Calculation
    // Combine specialization (F1) and proficiency (Level match)
    // Then apply role difficulty
    double combined = (baseF1 * 0.4) + (proficiencyFactor * 0.6);
    
    int finalScore = ((combined * 100) / role.difficulty).round().clamp(0, 100);

    return MatchResult(
      slug: role.slug,
      score: finalScore,
      matchedSkills: gaps['matched']!,
      weakSkills: gaps['weak']!,
      missingSkills: gaps['missing']!,
    );
  }

  /// Categorizes skills into Matched, Weak, or Missing.
  static Map<String, List<String>> analyzeGap(List<SkillModel> userSkills, CareerRole role) {
    final matched = <String>[];
    final weak = <String>[];
    final missing = <String>[];

    for (final req in role.requiredSkills) {
      final sk = userSkills.where((s) => RolesDB.isMatch(s.name, req)).firstOrNull;

      if (sk == null) {
        missing.add(req);
      } else if (sk.level >= 60) {
        matched.add(req);
      } else if (sk.level >= 20) {
        weak.add(req);
      } else {
        missing.add(req);
      }
    }

    return {
      'matched': matched,
      'weak': weak,
      'missing': missing,
    };
  }

  /// Compares user skills against a provided set of roles.
  static Map<String, MatchResult> computeRoleMatches(List<SkillModel> skills, Map<String, CareerRole> roles) {
    return roles.map((slug, role) => MapEntry(slug, computeMatch(skills, role)));
  }

  /// Returns the role with the highest match score from the provided set.
  static CareerRole? bestMatch(List<SkillModel> skills, Map<String, CareerRole> roles) {
    if (skills.isEmpty || roles.isEmpty) return null;
    final results = computeRoleMatches(skills, roles);
    if (results.isEmpty) return null;
    final best = results.entries.reduce((a, b) => a.value.score > b.value.score ? a : b);
    if (best.value.score < 10) return null; 
    return roles[best.key];
  }
}
