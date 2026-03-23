import '../models/roles_db.dart';

/// Result of skill validation.
/// [verified]   — passed all checks, safe to store immediately.
/// [unverified] — suspicious but plausible, shown to user for confirmation.
/// Rejected skills are dropped silently (soft skills, low-confidence, phrases).
class SkillValidationResult {
  final List<Map<String, dynamic>> verified;
  final List<Map<String, dynamic>> unverified;

  const SkillValidationResult({
    required this.verified,
    required this.unverified,
  });
}

/// Validation layer between AI skill extraction and Firestore storage.
///
/// Pipeline (per agreed architecture):
///   AI output → confidence filter → normalizeSkill → validate → dedupe verified → dedupe unverified
///
/// Buckets:
///   Hard reject  — confidence < 0.60, soft skill, phrase (> 4 words)
///   Unverified   — not found in role corpus (rare but real skills like Blender, LaTeX)
///   Verified     — passes all checks
class SkillValidator {
  // ── Lazy role skill corpus ──────────────────────────────────────
  // Built once from RolesDB on first use. O(1) lookups after that.
  static Set<String>? _roleSkillCorpus;

  static Set<String> _getCorpus() {
    if (_roleSkillCorpus != null) return _roleSkillCorpus!;
    final corpus = <String>{};
    for (final role in RolesDB.roles.values) {
      for (final skill in role.requiredSkills) {
        corpus.add(RolesDB.normalizeSkill(skill).toLowerCase());
      }
    }
    _roleSkillCorpus = corpus;
    return corpus;
  }

  // ── Soft skill blocklist ────────────────────────────────────────
  // Canonical lowercase. Add more as discovered in production.
  static const Set<String> _softSkills = {
    'communication',
    'leadership',
    'teamwork',
    'team spirit',
    'team player',
    'problem solving',
    'problem-solving',
    'critical thinking',
    'time management',
    'adaptability',
    'creativity',
    'work ethic',
    'attention to detail',
    'interpersonal skills',
    'organizational skills',
    'multitasking',
    'collaboration',
    'self-motivated',
    'self motivated',
    'analytical thinking',
    'decision making',
    'decision-making',
    'conflict resolution',
    'emotional intelligence',
    'presentation skills',
    'active listening',
    'positive attitude',
    'flexibility',
    'accountability',
    'dependability',
    'reliability',
    'initiative',
    'motivation',
    'passion',
    'enthusiasm',
    'hard working',
    'hardworking',
    'fast learner',
    'quick learner',
    'detail oriented',
    'detail-oriented',
    'open minded',
    'open-minded',
    'customer service',
    'customer focus',
    // Generic academic terms that aren't skills
    'computer science',
    'information technology',
    'technology',
    'programming',
    'software development',
    'web development',
    'mobile development',
    'engineering',
  };

  // ── Confidence threshold ────────────────────────────────────────
  static const double _confidenceThreshold = 0.60;

  /// Main entry point. Takes raw AI-extracted skills (with optional confidence)
  /// and returns two buckets: verified and unverified.
  ///
  /// Each skill map must have: 'name' (String), 'level' (int), 'category' (String)
  /// Optionally: 'confidence' (double) — if absent, defaults to 1.0 (trusted)
  static SkillValidationResult validate(List<Map<String, dynamic>> rawSkills) {
    final corpus = _getCorpus();

    // Step 1 — Confidence filter (hard reject below threshold)
    final afterConfidence = rawSkills.where((s) {
      final confidence = (s['confidence'] as num?)?.toDouble() ?? 1.0;
      return confidence >= _confidenceThreshold;
    }).toList();

    // Step 2 — Normalize skill names
    final normalized = afterConfidence.map((s) {
      final rawName = s['name'] as String? ?? '';
      final canonical = RolesDB.normalizeSkill(rawName);
      return {...s, 'name': canonical};
    }).toList();

    // Step 3 — Validate: sort into verified vs unverified
    final verifiedRaw = <Map<String, dynamic>>[];
    final unverifiedRaw = <Map<String, dynamic>>[];

    for (final skill in normalized) {
      final name = skill['name'] as String;
      final lower = name.toLowerCase().trim();
      final confidence = (skill['confidence'] as num?)?.toDouble() ?? 1.0;

      // Hard reject: soft skill
      if (_softSkills.contains(lower)) continue;

      // Hard reject: phrase too long (> 4 words) — likely a hallucinated description
      final wordCount = name.trim().split(RegExp(r'\s+')).length;
      if (wordCount > 4) continue;

      // Hard reject: empty name
      if (name.isEmpty) continue;

      // Semantic Check
      final inCorpus = corpus.contains(lower) ||
          corpus.any((c) => RolesDB.isMatch(name, c));

      // Bucket Logic (0.8+ is Auto-Add, 0.6+ and in corpus is Auto-Add, else Unverified)
      if (confidence >= 0.8 || (confidence >= _confidenceThreshold && inCorpus)) {
        verifiedRaw.add(skill);
      } else {
        unverifiedRaw.add(skill);
      }
    }

    // Step 4 — Deduplicate verified (after validation, not before)
    final verified = _deduplicate(verifiedRaw);

    // Step 5 — Deduplicate unverified separately
    final unverified = _deduplicate(unverifiedRaw);

    return SkillValidationResult(
      verified: verified,
      unverified: unverified,
    );
  }

  /// Deduplicates a skill list by canonical name.
  /// When duplicates exist, keeps the entry with the higher confidence/level.
  static List<Map<String, dynamic>> _deduplicate(
      List<Map<String, dynamic>> skills) {
    final Map<String, Map<String, dynamic>> unique = {};

    for (final skill in skills) {
      final name = (skill['name'] as String).toLowerCase();
      if (!unique.containsKey(name)) {
        unique[name] = skill;
      } else {
        // Keep the higher-confidence or higher-level entry
        final existingLevel = unique[name]!['level'] as int? ?? 0;
        final newLevel = skill['level'] as int? ?? 0;
        final existingConf =
            (unique[name]!['confidence'] as num?)?.toDouble() ?? 1.0;
        final newConf = (skill['confidence'] as num?)?.toDouble() ?? 1.0;

        if (newConf > existingConf || newLevel > existingLevel) {
          unique[name] = skill;
        }
      }
    }

    return unique.values.toList();
  }

  /// Invalidate corpus cache — call if RolesDB roles change at runtime.
  static void invalidateCorpus() => _roleSkillCorpus = null;
}
