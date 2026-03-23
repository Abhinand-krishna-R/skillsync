import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/roles_db.dart';
import '../models/extracted_skill.dart';

/// Serializes concurrent Groq API calls with a limit to avoid rate-limit bursts.
class AiQueue {
  static const int _maxConcurrent = 2; // Allow 2 requests at once
  static int _running = 0;
  static final List<Completer<void>> _waiting = [];

  static Future<T> run<T>(Future<T> Function() task) async {
    if (_running >= _maxConcurrent) {
      final waitCompleter = Completer<void>();
      _waiting.add(waitCompleter);
      await waitCompleter.future;
    }

    _running++;
    try {
      // Add a 45s absolute safety timeout to each request
      return await task().timeout(const Duration(seconds: 45));
    } finally {
      _running--;
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      }
    }
  }
}

/// Thrown when the Groq API key is missing or empty.
/// This surfaces as a real exception so callers can show a proper error
/// instead of a misleading "no skills found" or "connection error" message.
class AiKeyMissingException implements Exception {
  @override
  String toString() =>
      'Groq API key is missing. Add GROQ_API_KEY to your .env file '
      'and ensure .env is listed under flutter > assets in pubspec.yaml.';
}

/// Thrown when the Groq API returns a non-200 response after all retries.
class AiRequestException implements Exception {
  final int statusCode;
  final String message;
  AiRequestException(this.statusCode, this.message);
  @override
  String toString() => 'Groq API error $statusCode: $message';
}

/// AI Service using Groq API (llama-3.3-70b-versatile).
class AiService {
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  /// Increment this whenever the roadmap prompt in generateRoadmap changes.
  /// This will automatically invalidate existing caches in FirestoreService.
  static const int roadmapPromptVersion = 5;

  // ─────────────────────────────────────────────────────────────
  // KEY RESOLUTION
  // Priority: --dart-define at compile time → .env at runtime
  //
  // ROOT CAUSE FIX: The previous version silently returned '' on missing key,
  // which caused every AI feature to fail with misleading UI errors.
  // Now we throw AiKeyMissingException so the caller knows the real reason.
  //
  // REQUIRED pubspec.yaml entry for .env to load at runtime:
  //   flutter:
  //     assets:
  //       - .env
  // Without this, dotenv.load() in main.dart throws and is silently caught,
  // dotenv.env['GROQ_API_KEY'] returns null, and _apiKey was returning ''.
  // ─────────────────────────────────────────────────────────────
  static String get _apiKey {
    // Compile-time constant — only set if built with --dart-define=GROQ_API_KEY=xxx
    const fromDartDefine = String.fromEnvironment('GROQ_API_KEY');
    if (fromDartDefine.isNotEmpty) {
      return fromDartDefine.trim();
    }

    // Runtime fallback — requires .env listed as asset in pubspec.yaml
    final fromDotenv = dotenv.env['GROQ_API_KEY'] ?? '';
    return fromDotenv.trim();
  }

  /// Returns true if the API key is available. Use for pre-flight checks.
  static bool get hasApiKey => _apiKey.isNotEmpty;

  static String get apiKeySource {
    const fromDartDefine = String.fromEnvironment('GROQ_API_KEY');
    if (fromDartDefine.isNotEmpty) return 'dart-define';
    if (dotenv.env.containsKey('GROQ_API_KEY')) return '.env';
    return 'none';
  }

  // ─────────────────────────────────────────────────────────────
  // INTERNAL: Send request to Groq with retry
  // ─────────────────────────────────────────────────────────────
  static Future<String> _sendGroqRequest(
    String prompt, {
    required String feature,
    String? systemPrompt,
    int retries = 1,
    int maxTokens = 1500,
  }) async {
    return AiQueue.run(() async {
      final effectiveSystemPrompt = systemPrompt ??
          'You are a career intelligence assistant. Always respond with valid JSON only. No markdown, no explanation, no code fences.';

      final key = _apiKey;
      if (key.isEmpty) {
        debugPrint('AiService: GROQ_API_KEY is empty.');
        throw AiKeyMissingException();
      }

      final client = http.Client();
      try {
        for (int i = 0; i <= retries; i++) {
          try {
            final response = await client
                .post(
                  Uri.parse(_baseUrl),
                  headers: {
                    'Authorization': 'Bearer $key',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'model': _model,
                    'messages': [
                      {'role': 'system', 'content': effectiveSystemPrompt},
                      {'role': 'user', 'content': prompt},
                    ],
                    'temperature': 0.4,
                    'max_tokens': maxTokens,
                  }),
                )
                .timeout(const Duration(seconds: 30));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final content =
                  data['choices']?[0]?['message']?['content'] as String? ?? '';
              return content.trim();
            } else if (response.statusCode == 429) {
              debugPrint(
                  'AiService: Rate limited (429). Retry ${i + 1}/$retries');
              if (i < retries) {
                await Future.delayed(Duration(seconds: 2 * (i + 1)));
              } else {
                throw AiRequestException(response.statusCode, response.body);
              }
            } else if (response.statusCode == 401) {
              debugPrint('AiService: Invalid API key (401).');
              throw AiRequestException(
                  401, 'Invalid API key. Check GROQ_API_KEY value.');
            } else {
              debugPrint(
                  'AiService: HTTP ${response.statusCode}: ${response.body}');
              if (i >= retries) {
                throw AiRequestException(response.statusCode, response.body);
              }
            }
          } on TimeoutException {
            debugPrint('AiService: Request timed out (30s). Retry ${i + 1}/$retries');
            if (i >= retries) {
              throw AiRequestException(408, 'AI request timed out. Please try again.');
            }
            await Future.delayed(const Duration(seconds: 1));
          } on AiKeyMissingException {
            rethrow;
          } on AiRequestException {
            rethrow;
          } catch (e) {
            debugPrint('AiService: request error (attempt ${i + 1}): $e');
            if (i >= retries) rethrow;
            await Future.delayed(const Duration(seconds: 1));
          }
        }
        return '';
      } finally {
        client.close();
      }
    });
  }

  /// Robust markdown stripper — handles both object {} and array [] responses.

  static String _cleanJSON(String raw) {
    // 1. Remove trailing commas in objects and arrays
    // Regex matches a comma followed by closing brace/bracket, ignoring whitespace/newlines
    final trailingCommaRegex = RegExp(r',(\s*[}\]])');
    String cleaned = raw.replaceAllMapped(trailingCommaRegex, (match) => match.group(1)!);
    
    // 2. Remove comments (AI sometimes adds them)
    final commentRegex = RegExp(r'//.*$|/\*[\s\S]*?\*/', multiLine: true);
    cleaned = cleaned.replaceAll(commentRegex, '');
    
    return cleaned.trim();
  }

  /// Robust JSON decode — extract valid JSON structure from noisy AI responses.
  /// If [prefersObject] is true, it will look for the outermost { } even if a [ ] appears earlier.
  static dynamic safeDecodeAI(String raw, {bool prefersObject = false}) {
    try {
      if (raw.isEmpty) return null;

      raw = raw.trim();

      // Preliminary clean: Strip markdown fences if any remain
      raw = raw.replaceAll("```json", "").replaceAll("```", "");

      // Handle raw string escaping if AI returns JSON inside a string
      if (raw.startsWith('"') && raw.endsWith('"') && raw.length > 2) {
        raw = raw.substring(1, raw.length - 1).replaceAll('\\"', '"').replaceAll('\\n', '\n');
      }

      int firstBracket = raw.indexOf('[');
      int firstBrace = raw.indexOf('{');

      // If prefersObject is true, we ONLY prioritize the brace if it actually exists.
      bool tryObjectFirst = prefersObject 
          ? (firstBrace != -1) 
          : (firstBrace != -1 && (firstBracket == -1 || firstBrace < firstBracket));

      if (tryObjectFirst) {
        // 1. Try Object Extraction
        int lastBrace = raw.lastIndexOf('}');
        if (lastBrace > firstBrace) {
          final jsonPart = _cleanJSON(raw.substring(firstBrace, lastBrace + 1));
          try {
             // AI recovery for multiple objects — common in some feature responses
            if (jsonPart.contains('}\n{') || jsonPart.contains('},{')) {
               return jsonDecode("[$jsonPart]");
            }
            return jsonDecode(jsonPart);
          } catch (_) {
             // If JSON is slightly truncated at start, try prefixing it
             if (!jsonPart.startsWith('{')) {
               try { return jsonDecode('{$jsonPart}'); } catch (__) {}
             }
          }
        }
      }

      // 2. Try Array Extraction (ONLY if prefersObject is false OR object extraction failed)
      if (firstBracket != -1) {
        int lastBracket = raw.lastIndexOf(']');
        if (lastBracket > firstBracket) {
          final jsonPart = _cleanJSON(raw.substring(firstBracket, lastBracket + 1));
          
          // If we prefer an object, don't return an array if it's clearly just a field's value
          bool ignoreArray = prefersObject && raw.contains(':') && raw.indexOf(':') < firstBracket;

          if (!ignoreArray) {
            try {
              return jsonDecode(jsonPart);
            } catch (_) {}
          }
        }
      }

      // 3. Fallback: Try Object Extraction if it wasn't tried first
      if (!tryObjectFirst && firstBrace != -1) {
        int lastBrace = raw.lastIndexOf('}');
        if (lastBrace > firstBrace) {
          final jsonPart = _cleanJSON(raw.substring(firstBrace, lastBrace + 1));
          try {
            return jsonDecode(jsonPart);
          } catch (_) {}
        }
      }

      // 4. Final attempt: Direct decode or throw
      return jsonDecode(_cleanJSON(raw));
    } catch (e) {
      return null;
    }
  }

  /// Deprecated: use [safeDecodeAI] instead.
  static dynamic _safeDecode(String raw) => safeDecodeAI(raw);

  // ─────────────────────────────────────────────────────────────
  // SEMANTIC SKILL MATCHING
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> semanticGapAnalysis({
    required List<String> userSkills,
    required List<String> roleSkills,
  }) async {
    const fallback = {'match': [], 'weak': [], 'missing': [], 'score': 0};
    if (userSkills.isEmpty || roleSkills.isEmpty) {
      return {...fallback, 'missing': roleSkills};
    }

    const systemPrompt = '''
You are a career skill matching engine.
Compare USER SKILLS with ROLE REQUIRED SKILLS using semantic understanding.
"match" = strong match. "weak" = related but weaker. "missing" = not related.
Score = (match_count / total_role_skills) * 100
Return STRICT JSON ONLY — no markdown, no explanation, no fences:
{"match": [], "weak": [], "missing": [], "score": number}''';

    final userPrompt = '''
USER SKILLS:
${userSkills.join("\n")}

ROLE REQUIRED SKILLS:
${roleSkills.join("\n")}''';

    try {
      final raw = await _sendGroqRequest(
        userPrompt,
        feature: 'gapAnalysis',
        systemPrompt: systemPrompt,
        maxTokens: 500,
      );
      final decoded = _safeDecode(raw);
      if (decoded == null) {
        return {...fallback, 'missing': roleSkills};
      }
      
      final score = (decoded['score'] as num?)?.round() ?? 0;
      return {
        'match': List<String>.from(decoded['match'] is List ? decoded['match'] : []),
        'weak': List<String>.from(decoded['weak'] is List ? decoded['weak'] : []),
        'missing': List<String>.from(decoded['missing'] is List ? decoded['missing'] : roleSkills),
        'score': score,
      };
    } catch (e) {
      debugPrint('AiService.semanticGapAnalysis error: $e');
      return {...fallback, 'missing': roleSkills};
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DYNAMIC ROLE SUGGESTIONS
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> generateRoleSuggestions(
      List<String> userSkills) async {
    if (userSkills.isEmpty) return [];

    const systemPrompt = '''
You are a career mapping AI. Analyze the user's skills and recommend the 3 most appropriate specific job roles.
Return STRICT JSON ONLY — no markdown, no fences:
{
  "roles": [
    {
      "name": "Software Engineer",
      "slug": "software_engineer",
      "category": "Engineering",
      "careerCluster": "Software",
      "demand": "High",
      "salary": "e.g. ₹5–20 LPA or \$80k–\$120k USD",
      "description": "Short description of the role.",
      "requiredSkills": ["Skill 1", "Skill 2", "Skill 3", "Skill 4", "Skill 5", "Skill 6", "Skill 7", "Skill 8", "Skill 9", "Skill 10"],
      "weights": {
        "Skill 1": 1.8,
        "Skill 2": 1.5,
        "Skill 3": 1.3,
        "Skill 4": 1.1,
        "Skill 5": 1.0,
        "Skill 6": 0.9,
        "Skill 7": 0.8,
        "Skill 8": 0.7,
        "Skill 9": 0.6,
        "Skill 10": 0.6
      },
      "requiredLevels": {
        "Skill 1": 85,
        "Skill 2": 80,
        "Skill 3": 75,
        "Skill 4": 75,
        "Skill 5": 70,
        "Skill 6": 70,
        "Skill 7": 65,
        "Skill 8": 65,
        "Skill 9": 60,
        "Skill 10": 55
      },
      "tools": ["Tool 1", "Tool 2", "Tool 3"],
      "aiTips": ["Tip 1", "Tip 2", "Tip 3"],
      "qualificationRequired": false,
      "qualifications": ["Degree 1"],
      "qualificationNote": "Optional note."
    }
  ]
}

Rules for weights:
- Core defining skill: 1.5–1.8
- Important but not defining: 1.0–1.4
- Supporting skill: 0.6–0.9
- Every skill in requiredSkills MUST appear in weights
- salary: Use ₹X–Y LPA format for Indian market roles, or \$X–\$Y USD for international roles. Match the market context of the role.
- careerCluster: One word (e.g., Frontend, Backend, AI, DevOps, Mobile, Data, Business, Design, Engineering, Security, Cloud)

Rules for requiredLevels:
- Must be expert: 80–90
- Should be solid: 65–79
- Basic familiarity enough: 50–64
- Every skill in requiredSkills MUST appear in requiredLevels

Include 8-12 skills per role. Cover ALL skills a professional needs, not just obvious ones.
NO markdown, NO fences. Only valid JSON.''';

    final userPrompt = 'USER SKILLS:\n${userSkills.join("\n")}';

    try {
      final raw = await _sendGroqRequest(
        userPrompt,
        feature: 'roleSuggestions',
        systemPrompt: systemPrompt,
        maxTokens: 1500,
      );
      final decoded = _safeDecode(raw);
      if (decoded == null) return [];

      List<Map<String, dynamic>> rawRoles = [];
      if (decoded is Map) {
        final rolesField = decoded['roles'];
        if (rolesField is List) {
          rawRoles = rolesField
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      } else if (decoded is List) {
        rawRoles = decoded
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }

      if (rawRoles.isEmpty) {
        debugPrint('AiService.generateRoleSuggestions: No roles found in decoded response');
        return [];
      }
      
      return rawRoles.map((r) => _normalizeRoleSkills(r)).toList();
    } catch (e) {
      debugPrint('AiService.generateRoleSuggestions error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RESOURCE URL BUILDER
  // Converts platform + search_query from AI into a guaranteed working URL.
  // Never relies on AI to produce a URL directly — they hallucinate.
  // ─────────────────────────────────────────────────────────────
  static String buildResourceUrl(Map<String, dynamic> resource) {
    final platform = (resource['platform'] as String? ?? 'youtube').toLowerCase();
    final rawSearch = resource['search'] as String? ??
        resource['title'] as String? ??
        'programming tutorial';
    final query = Uri.encodeQueryComponent(rawSearch);

    return switch (platform) {
      'youtube'        => 'https://www.youtube.com/results?search_query=$query',
      'freecodecamp'   => 'https://www.freecodecamp.org/news/search/?query=$query',
      'pub_dev'        => 'https://pub.dev/packages?q=$query',
      'github'         => 'https://github.com/search?q=$query&type=repositories',
      'mdn'            => 'https://developer.mozilla.org/en-US/search?q=$query',
      'dev_to'         => 'https://dev.to/search?q=$query',
      'official_docs'  => 'https://www.google.com/search?q=${Uri.encodeQueryComponent('$rawSearch official documentation')}',
      _                => 'https://www.youtube.com/results?search_query=$query',
    };
  }

  /// Returns a display label for the platform (for UI use)
  static String platformLabel(Map<String, dynamic> resource) {
    final platform = (resource['platform'] as String? ?? 'youtube').toLowerCase();
    return switch (platform) {
      'youtube'       => 'YouTube',
      'freecodecamp'  => 'freeCodeCamp',
      'pub_dev'       => 'pub.dev',
      'github'        => 'GitHub',
      'mdn'           => 'MDN Docs',
      'dev_to'        => 'dev.to',
      'official_docs' => 'Official Docs',
      _               => 'YouTube',
    };
  }

  /// Creates a deterministic MD5 hash for a set of skill names.
  static String hashSkills(List<String> skills) {
    if (skills.isEmpty) return 'empty';
    // Deterministic: Normalize, lowercase, sort, unique
    final processed = skills
        .map((s) => RolesDB.normalizeSkill(s).toLowerCase())
        .toSet()
        .toList()
      ..sort();
    final input = processed.join('|');
    return md5.convert(utf8.encode(input)).toString();
  }

  // ─────────────────────────────────────────────────────────────
  // 1. EXTRACT SKILLS FROM RESUME TEXT
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> extractSkillsFromText(
      String resumeText) async {
    if (resumeText.trim().isEmpty) return [];

    final text = _smartTruncate(resumeText, maxChars: 3500);

    final prompt = '''
You are a resume analysis system. Extract all technical and professional skills from the resume text below.

Return ONLY a JSON object in this exact format:
{
  "skills": [
    {"name": "Flutter", "level": 75, "category": "Mobile", "confidence": 0.92},
    {"name": "Firebase", "level": 65, "category": "Backend", "confidence": 0.85}
  ]
}

Rules:
1. Extract programming languages, frameworks, databases, tools, and platforms only.
2. Infer skills from project descriptions and work experience.
3. Categories: Programming, Mobile, Web, Data & AI, Design, DevOps, Cloud, Security, Database, Tools, or Other.
4. Estimate proficiency level (1–100):
   - Mentioned as keyword only, no context: 55â60
   - Used in one academic or personal project: 62â68
   - Used in one internship or bootcamp project: 68â72
   - Used in one production/work project: 73â78
   - Used across multiple work or production projects: 79â84
   - Led or architected solutions using this skill: 85â90
   - Deep expertise, senior/lead context, multiple years: 91â95
   Apply carefully: most people should NOT score above 80 unless the resume shows lead/architect/multi-year depth.
5. Confidence score (0.0–1.0):
   - Explicitly named skill: 0.85–0.95
   - Inferred from project description: 0.65–0.80
   - Ambiguous or generic: 0.40–0.60
6. DO NOT extract: soft skills (communication, teamwork), generic words (technology, computer science), or office tools (Word, PowerPoint, Excel unless explicitly used for data analysis).
7. DO NOT return synonyms as separate entries (e.g. "Node" and "Node.js" → return only "Node.js").
8. Return 5–25 skills if present. Never return an empty list if skills exist.
9. NO markdown, NO code fences, NO explanation. Only valid JSON.

Resume text:
"""
$text
"""

The response MUST start with { and end with }. Do not return an array alone.
''';

    try {
      final raw = await _sendGroqRequest(
        prompt, 
        feature: 'resumeExtraction',
        maxTokens: 2000, 
        retries: 2,
      );
      final dynamic decoded = _safeDecode(raw);
      if (decoded == null) return [];

      List<dynamic> rawList = [];
      if (decoded is Map) {
        final s = decoded['skills'];
        if (s is List) {
          rawList = s;
        }
      } else if (decoded is List) {
        rawList = decoded;
      }

      if (rawList.isEmpty) return [];

      final Map<String, ExtractedSkill> uniqueSkills = {};

      for (var e in rawList) {
        // AI Recovery: If AI returned a list of strings instead of objects
        if (e is String) {
          final canonical = RolesDB.canonicalName(e);
          final normalized = canonical.toLowerCase();
          if (!uniqueSkills.containsKey(normalized)) {
            uniqueSkills[normalized] = ExtractedSkill(name: canonical);
          }
          continue;
        }

        if (e is! Map) continue;

        final skill = ExtractedSkill.fromJson(Map<String, dynamic>.from(e));
        if (skill.name.isEmpty) continue;

        final canonical = RolesDB.canonicalName(skill.name);
        final normalized = canonical.toLowerCase();

        // Keep the one with highest confidence
        if (!uniqueSkills.containsKey(normalized) ||
            skill.confidence > uniqueSkills[normalized]!.confidence) {
          
          // Carry over the canonical name during normalization
          uniqueSkills[normalized] = ExtractedSkill(
            name: canonical,
            level: skill.level,
            category: skill.category,
            confidence: skill.confidence,
          );
        }
      }

      return uniqueSkills.values.map((s) => s.toMap()).toList();
    } catch (e) {
      debugPrint('AiService.extractSkillsFromText error: $e');
      rethrow; // Let ResumeService surface the real error to the UI
    }
  }

  static String _smartTruncate(String text, {required int maxChars}) {
    if (text.length <= maxChars) return text;
    // Keep 1/3 at start, 2/3 at end (usually more relevant experience at end of extraction prompt text)
    final head = text.substring(0, (maxChars * 0.3).toInt());
    final tail = text.substring(text.length - (maxChars * 0.7).toInt());
    return '$head\n...\n$tail';
  }

  // ─────────────────────────────────────────────────────────────
  // 2. SUGGEST SKILL CATEGORY (for manual entry)
  // ─────────────────────────────────────────────────────────────
  static Future<String> suggestSkillCategory(String skillName) async {
    if (skillName.trim().isEmpty) return 'Other';

    final prompt = '''
What is the best category for this skill: "$skillName"?
Choose exactly one from this list:
Programming, Mobile, Web, Data & AI, Design, DevOps, Cloud, Security, Database, Tools, Clinical, Healthcare, Business, Finance, Education, Marketing, Management, Other

Category guidance:
- Cloud: AWS, GCP, Azure, cloud platforms, serverless, cloud-native tools
- Security: cybersecurity, penetration testing, SIEM, firewalls, cryptography, ethical hacking, network security
- DevOps: CI/CD pipelines, Docker, Kubernetes, Terraform, infrastructure-as-code, monitoring
- Data & AI: machine learning, deep learning, data science, NLP, computer vision, analytics, statistics
- Database: SQL, NoSQL, databases, ORMs, query languages, Redis, Elasticsearch
- Programming: languages and core programming concepts not covered above
- Mobile: iOS, Android, Flutter, React Native, cross-platform frameworks
- Web: frontend frameworks, HTML, CSS, browser APIs, SSR
- Tools: IDEs, version control, testing frameworks, productivity tools
Return ONLY a JSON object: {"category": "Mobile"}
''';

    try {
      final raw = await _sendGroqRequest(
        prompt, 
        feature: 'skillCategory',
        maxTokens: 50,
      );
      final decoded = _safeDecode(raw);
      return decoded?['category'] as String? ?? 'Other';
    } catch (e) {
      return 'Other';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 3. GENERATE PERSONALIZED ROADMAP
  // ─────────────────────────────────────────────────────────────
  //
  // RESOURCE LINK FIX:
  // Old prompt asked for raw URLs → AI hallucinated or returned "google.com".
  // New approach: AI returns platform + search_query.
  // buildResourceUrl() constructs a guaranteed-working search URL.
  static Future<List<Map<String, dynamic>>> generateRoadmap({
    required String targetRole,
    required List<String> userSkills,
    required List<String> missingSkills,
    List<Map<String, dynamic>>? skillsWithLevels,
    List<String>? weakSkills,
    int? currentScore,
  }) async {

    final prompt = '''
Target Role: \$targetRole
\${scoreContext}
User's Current Skills with Proficiency:
\$skillContext

Skills Needing Improvement (user has them, below required level):
\$weakContext

Skills to Learn from Scratch:
\${missingSkills.join(', ')}

TASK: Generate a personalised learning roadmap of exactly 7 modules for \$targetRole.
Tailor difficulty to the user's skill levels — skip basics they already know, go deeper where they are weak.

Return ONLY a **valid JSON array** of learning steps.

Each step must follow this structure:

{
"title": "Specific learning topic",
"description": "Detailed explanation of what the learner will master including tools, frameworks, or concepts",
"skills": ["PrimaryMissingSkill", "IntegratedSkill"],
"hours": 12,
"order": 1,
"resources": [
{
"title": "Exact course or documentation name",
"platform": "official_docs | youtube | coursera | freecodecamp | blog | github",
"search": "direct documentation URL OR precise search query"
}
],
"practice": [
"Concrete technical challenge",
"Portfolio-ready project"
]
}

Important Rules:

1. Generate EXACTLY 7 modules. Not 5, not 6, not 8. Exactly 7. Each module covers a distinct topic.

2. Each title must be a **real learning topic**, for example:

   * "Asynchronous Programming in Node.js"
   * "Advanced State Management with Redux Toolkit"
   * "MongoDB Aggregation Pipelines"
   * "Feature Engineering for Machine Learning"

3. Do NOT use generic titles such as:

   * "Module 1"
   * "Learning Step"
   * "Introduction"
   * "Core Skills"

4. Resources must reference **real educational material**, such as:

   * Official documentation
   * Recognized online courses
   * Well-known tutorials
   * Influential technical books

5. Practice tasks must be **GitHub-portfolio quality**, such as:

   * Building an application
   * Implementing a production pattern
   * Writing automated tests
   * Creating a deployable service

6. Hours should reflect **realistic learning effort**:

   * 5–10 hours for small tools or libraries
   * 10–20 hours for frameworks
   * 20+ hours for complex systems

7. Each step should progressively move from **skill acquisition → real project usage**.

8. Return ONLY a valid JSON ARRAY. The response must start with [ and end with ]. Do not return multiple objects outside an array.
''';

    try {
      final raw = await _sendGroqRequest(
        prompt,
        feature: 'roadmap',
        maxTokens: 3500,
        retries: 2,
      );
      
      debugPrint('AiService: Raw Roadmap Response:\n$raw');

      final decoded = safeDecodeAI(raw);
      if (decoded == null || decoded is! List) {
        debugPrint('AiService: Roadmap invalid JSON type (expected List, got ${decoded?.runtimeType})');
        return _fallbackRoadmap(targetRole, missingSkills);
      }

      // Safe casting to handle stray nulls or non-map entries
      final List<Map<String, dynamic>> rawModules = decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      // All AI modules accepted — count enforced by prompt
      final List<Map<String, dynamic>> modules = rawModules;

      if (!_isValidRoadmap(modules)) {
        debugPrint('AiService: Roadmap failed validation schema.');
        return _fallbackRoadmap(targetRole, missingSkills);
      }

      // Inject default skillBoost if missing or empty
      for (final m in modules) {
        final currentBoost = m['skillBoost'];
        if (currentBoost == null || (currentBoost is Map && currentBoost.isEmpty)) {
          final List<String> skillsInModule = List<String>.from(m['skills'] ?? []);
          m['skillBoost'] = {for (final s in skillsInModule) s: 5};
        }
      }

      debugPrint('AiService: Roadmap accepted (${modules.length} modules)');
      return modules;
    } catch (e) {
      debugPrint('AiService.generateRoadmap error: $e');
      return _fallbackRoadmap(targetRole, missingSkills);
    }
  }

  static bool _isValidRoadmap(List<dynamic> modules) {
    if (modules.length < 5) return false;
    return modules.every(
      (m) =>
          m is Map &&
          m.containsKey('title') &&
          m.containsKey('skills') &&
          m.containsKey('hours') &&
          m.containsKey('order') &&
          m.containsKey('resources') &&
          m.containsKey('practice'),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. GENERATE INTERVIEW INSIGHTS (cached globally per role)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateInterviewInsights(
      String roleName, {
    List<String> userSkills = const [],
    List<String> matchedSkills = const [],
    List<String> missingSkills = const [],
  }) async {
    const systemPrompt = '''
You are a calm and supportive career advisor.
Explain how interviews work for the given job role.
Return STRICT JSON ONLY — no markdown, no explanation, no code fences.''';

    // Build personalised skill context so tips are relevant to what the user knows
    final String skillSection = userSkills.isNotEmpty
        ? '''
The candidate's current skills: ${userSkills.take(15).join(', ')}
Skills they already match for this role: ${matchedSkills.isNotEmpty ? matchedSkills.join(', ') : 'None confirmed yet'}
Skills they still need: ${missingSkills.isNotEmpty ? missingSkills.take(8).join(', ') : 'Not identified yet'}

Use this context to:
- Tailor common_questions to topics the interviewer will probe based on their skill gaps
- Make preparation_tips specific to what they know and what they need to demonstrate
'''
        : '';

    final userPrompt = '''
Explain how interviews work for the role: "$roleName"
$skillSection
Provide calm, helpful guidance in this exact JSON format:
{
  "overview": "2-3 sentence description of what interviews are like for this role",
  "interview_types": ["Type 1", "Type 2", "Type 3"],
  "common_questions": ["Question 1?", "Question 2?", "Question 3?", "Question 4?"],
  "preparation_tips": ["Tip 1", "Tip 2", "Tip 3", "Tip 4"],
  "calm_advice": ["Calm piece of advice 1", "Calm piece of advice 2", "Calm piece of advice 3"]
}

Rules:
- Be specific to "$roleName", not generic career advice
- interview_types: 3-4 common formats for this role
- common_questions: 4-5 real questions a hiring manager would actually ask, specific to this role
- preparation_tips: 4 practical steps tailored to this candidate's skill profile if provided
- calm_advice: 3 reassuring tips to reduce anxiety
- Keep tone supportive, never intimidating
- Increase maxTokens budget is 1000 — use it for detailed, specific answers''';

    try {
      final raw = await _sendGroqRequest(
        userPrompt,
        feature: 'interviewInsights',
        systemPrompt: systemPrompt,
        maxTokens: 1000,
      );
      final decoded = _safeDecode(raw);
      if (decoded == null || !decoded.containsKey('overview')) {
        return _fallbackInterviewInsights(roleName);
      }
      return {
        'overview': decoded['overview'] as String? ?? '',
        'interview_types':
            List<String>.from(decoded['interview_types'] ?? []),
        'common_questions':
            List<String>.from(decoded['common_questions'] ?? []),
        'preparation_tips':
            List<String>.from(decoded['preparation_tips'] ?? []),
        'calm_advice': List<String>.from(decoded['calm_advice'] ?? []),
      };
    } catch (e) {
      debugPrint('AiService.generateInterviewInsights error: $e');
      return _fallbackInterviewInsights(roleName);
    }
  }

  static Map<String, dynamic> _fallbackInterviewInsights(String role) => {
        'overview':
            'Interviews for $role typically include a discussion about your skills, '
            'past experience, and how you approach problems.',
        'interview_types': [
          'Technical Discussion',
          'Behavioral Interview',
          'Portfolio / Project Review',
        ],
        'common_questions': [
          'Tell me about yourself and your experience.',
          'Describe a challenging project you worked on.',
          'How do you approach learning new skills?',
          'What are your strengths in this field?',
        ],
        'preparation_tips': [
          'Review your own projects and be ready to explain them clearly.',
          'Practice answering common questions out loud before the interview.',
          'Research the company and the specific role.',
          'Prepare 2-3 questions to ask the interviewer.',
        ],
        'calm_advice': [
          'Take a breath before answering — it\'s perfectly fine to pause.',
          'Explain your thought process even if you don\'t know the full answer.',
          'It\'s okay to say "I\'m not sure but I would approach it by..."',
        ],
      };

  // ─────────────────────────────────────────────────────────────
  // 5. GENERATE ROLE PROFILE (for unknown roles in Search)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> generateRoleProfile(
      String roleName) async {
    final prompt = '''
Return the following JSON object for the role: "$roleName"

{
  "title": "$roleName",
  "description": "2-3 sentence description of what this role does",
  "category": "Category",
  "careerCluster": "Cluster",
  "demand": "High",
  "salary": "₹X–Y LPA",
  "requiredSkills": ["Skill1", "Skill2", "Skill3"],
  "weights": { "Skill1": 1.8, "Skill2": 1.5 },
  "requiredLevels": { "Skill1": 85, "Skill2": 80 },
  "tools": ["Tool1", "Tool2"],
  "aiTips": ["Tip1", "Tip2", "Tip3", "Tip4"],
  "qualificationRequired": false,
  "qualifications": ["B.Tech"],
  "qualificationNote": "Note"
}

Return ONLY a SINGLE JSON object.
The response MUST start with { and end with }. Do NOT return as a list.
Do NOT start with arrays. Do NOT include explanations.

Example required format:
{
  "title": "$roleName",
  "description": "...",
  "category": "...",
  "careerCluster": "...",
  "demand": "...",
  "salary": "...",
  "requiredSkills": [],
  "weights": {},
  "requiredLevels": {},
  "tools": [],
  "aiTips": []
}
''';

    try {
      final raw = await _sendGroqRequest(
        prompt, 
        feature: 'roleProfile',
        retries: 2, 
        maxTokens: 2000,
      );
      if (raw.isEmpty) {
        debugPrint('AiService.generateRoleProfile: Received empty response');
        return null;
      }
      
      final decoded = safeDecodeAI(raw, prefersObject: true);
      Map<String, dynamic>? roleMap;
      
      if (decoded is Map) {
        roleMap = Map<String, dynamic>.from(decoded);
      } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        roleMap = Map<String, dynamic>.from(decoded.first as Map);
      }

      if (roleMap == null) {
        debugPrint('AiService.generateRoleProfile: Decode failed or invalid type for $roleName');
        debugPrint('AiService.generateRoleProfile: Raw snippet: ${raw.length > 300 ? raw.substring(0, 300) : raw}');
        return null;
      }
      
      return _normalizeRoleSkills(roleMap);
    } catch (e) {
      debugPrint('AiService.generateRoleProfile error for $roleName: $e');
      return null;
    }
  }

  /// Normalizes skill names in a role profile/suggestion to match RolesDB canonical names.
  static Map<String, dynamic> _normalizeRoleSkills(Map<String, dynamic> role) {
    // Definitive extraction of only the fields we actually use
    final title = role['title']?.toString() ?? 'Unknown Role';
    final description = role['description']?.toString() ?? '';
    final category = role['category']?.toString() ?? 'Other';
    final cluster = role['careerCluster']?.toString() ?? 'General';
    final demand = role['demand']?.toString() ?? 'High';
    final salary = role['salary']?.toString() ?? 'Varies';
    
    final rawSkills = role['requiredSkills'] is List ? role['requiredSkills'] as List : [];
    final Map<String, dynamic> weights = role['weights'] is Map ? Map<String, dynamic>.from(role['weights'] as Map) : {};
    final Map<String, dynamic> levels = role['requiredLevels'] is Map ? Map<String, dynamic>.from(role['requiredLevels'] as Map) : {};

    final List<String> normalizedSkills = [];
    final Map<String, double> normalizedWeights = {};
    final Map<String, int> normalizedLevels = {};

    for (var s in rawSkills) {
      if (s == null) continue;
      final skillName = s.toString();
      final canonical = RolesDB.canonicalName(skillName);
      normalizedSkills.add(canonical);

      // Robust type conversion for weights (handle String, int, double)
      final rawWeight = weights[skillName] ?? weights[canonical] ?? 1.0;
      double weightValue = 1.0;
      if (rawWeight is num) {
        weightValue = rawWeight.toDouble();
      } else if (rawWeight is String) {
        weightValue = double.tryParse(rawWeight) ?? 1.0;
      }

      // Robust type conversion for levels (handle String, int, double)
      final rawLevel = levels[skillName] ?? levels[canonical] ?? 60;
      int levelValue = 60;
      if (rawLevel is num) {
        levelValue = rawLevel.toInt();
      } else if (rawLevel is String) {
        levelValue = int.tryParse(rawLevel) ?? 60;
      }

      normalizedWeights[canonical] = weightValue;
      normalizedLevels[canonical] = levelValue;
    }

    return {
      'title': title,
      'description': description,
      'category': category,
      'careerCluster': cluster,
      'demand': demand,
      'salary': salary,
      'requiredSkills': normalizedSkills,
      'weights': normalizedWeights,
      'requiredLevels': normalizedLevels,
      'tools': role['tools'] is List ? List<String>.from(role['tools']) : [],
      'aiTips': role['aiTips'] is List ? List<String>.from(role['aiTips']) : [],
      'roadmap': role['roadmap'] is List ? List<String>.from(role['roadmap']) : [],
      'qualificationRequired': role['qualificationRequired'] ?? false,
      'qualifications': role['qualifications'] is List ? List<String>.from(role['qualifications']) : [],
      'qualificationNote': role['qualificationNote']?.toString() ?? '',
    };
  }

  // ─────────────────────────────────────────────────────────────
  // FALLBACK ROADMAP — 7 modules, real resources, used only when
  // AI generation or JSON parsing fails completely.
  // ─────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _fallbackRoadmap(
    String role,
    List<String> missingSkills,
  ) {
    // Distribute missing skills evenly across 7 modules
    final skillsPool = missingSkills.isNotEmpty ? missingSkills : [role];
    List<String> _skillsFor(int i) {
      final start = i * 2;
      if (start >= skillsPool.length) return [skillsPool.last];
      final end = (start + 2).clamp(0, skillsPool.length);
      return skillsPool.sublist(start, end);
    }

    final modules = [
      {
        'title': 'Foundations & Environment Setup',
        'description':
            'Set up your complete development environment and understand the core concepts, architecture, and ecosystem of $role. Learn the tooling, folder structure, and conventions used in production.',
        'skills': _skillsFor(0),
        'hours': 10,
        'order': 1,
        'resources': [
          {
            'title': 'Official $role Documentation — Getting Started',
            'platform': 'official_docs',
            'search': '$role official documentation getting started guide'
          },
          {
            'title': '$role Crash Course for Beginners — Traversy Media',
            'platform': 'youtube',
            'search': '$role crash course beginners Traversy Media'
          }
        ],
        'practice': [
          'Install and configure the full $role development environment',
          'Build and run your first Hello World project with proper project structure',
          'Document your environment setup in a README and push to GitHub'
        ],
        'skillBoost': {for (final s in _skillsFor(0)) s: 5},
      },
      {
        'title': 'Core Language & Syntax Deep Dive',
        'description':
            'Master the fundamental language features, data structures, and patterns essential to $role. Focus on the constructs you will use in every real project.',
        'skills': _skillsFor(1),
        'hours': 14,
        'order': 2,
        'resources': [
          {
            'title': '$role Language Guide — Official Docs',
            'platform': 'official_docs',
            'search': '$role language syntax guide official documentation'
          },
          {
            'title': '$role Full Course — freeCodeCamp',
            'platform': 'freecodecamp',
            'search': '$role full course tutorial freeCodeCamp'
          }
        ],
        'practice': [
          'Complete 10 focused exercises covering core $role syntax and data structures',
          'Build a command-line utility or script using only core language features',
          'Write unit tests for each utility function and publish the repo on GitHub'
        ],
        'skillBoost': {for (final s in _skillsFor(1)) s: 5},
      },
      {
        'title': 'Working with APIs & Data',
        'description':
            'Learn to fetch, send, and handle real data in $role. Understand async patterns, error handling, JSON serialisation, and REST API integration.',
        'skills': _skillsFor(2),
        'hours': 16,
        'order': 3,
        'resources': [
          {
            'title': 'REST API Integration in $role — Official Docs',
            'platform': 'official_docs',
            'search': '$role HTTP REST API integration official documentation'
          },
          {
            'title': '$role API & Async Programming — Fireship',
            'platform': 'youtube',
            'search': '$role async programming API Fireship tutorial'
          }
        ],
        'practice': [
          'Integrate a free public API (e.g. OpenWeather or GitHub API) into a $role project',
          'Build a data-fetching screen with loading, error, and success states',
          'Add caching so the app works offline and publish a demo on GitHub'
        ],
        'skillBoost': {for (final s in _skillsFor(2)) s: 5},
      },
      {
        'title': 'State Management & Architecture',
        'description':
            'Master state management patterns used in production $role applications. Learn when to use local vs global state and how to structure scalable, maintainable code.',
        'skills': _skillsFor(3),
        'hours': 18,
        'order': 4,
        'resources': [
          {
            'title': 'State Management Patterns — Official $role Docs',
            'platform': 'official_docs',
            'search': '$role state management patterns official guide'
          },
          {
            'title': '$role State Management Full Course — The Net Ninja',
            'platform': 'youtube',
            'search': '$role state management full course The Net Ninja'
          }
        ],
        'practice': [
          'Refactor a stateful project to use a proper state management solution',
          'Build a multi-screen app with shared global state and navigation',
          'Write integration tests covering 3 key user flows and document architecture decisions'
        ],
        'skillBoost': {for (final s in _skillsFor(3)) s: 5},
      },
      {
        'title': 'Database & Persistence',
        'description':
            'Integrate local and remote databases into your $role projects. Learn CRUD operations, real-time updates, and proper data modelling for production applications.',
        'skills': _skillsFor(4),
        'hours': 16,
        'order': 5,
        'resources': [
          {
            'title': 'Database Integration Guide — $role Official Docs',
            'platform': 'official_docs',
            'search': '$role database integration local storage official docs'
          },
          {
            'title': '$role with Firebase Full Course — Academind',
            'platform': 'youtube',
            'search': '$role Firebase full course Academind Maximilian'
          }
        ],
        'practice': [
          'Add local data persistence to a previous project (CRUD with a local database)',
          'Connect a real-time remote database and implement live sync across screens',
          'Deploy the app and demonstrate real-time data updates in a short screen recording'
        ],
        'skillBoost': {for (final s in _skillsFor(4)) s: 5},
      },
      {
        'title': 'Testing, Debugging & Code Quality',
        'description':
            'Build confidence in your $role code with unit, integration, and end-to-end tests. Learn debugging tools, linting, and code review practices used in professional teams.',
        'skills': _skillsFor(5),
        'hours': 14,
        'order': 6,
        'resources': [
          {
            'title': 'Testing Guide — $role Official Documentation',
            'platform': 'official_docs',
            'search': '$role testing unit integration testing official guide'
          },
          {
            'title': '$role Testing Masterclass — Fireship',
            'platform': 'youtube',
            'search': '$role testing tutorial unit integration Fireship'
          }
        ],
        'practice': [
          'Add unit tests achieving 70%+ coverage on a core module of your project',
          'Set up a CI pipeline with GitHub Actions that runs tests on every push',
          'Perform a code review on your own codebase and refactor 3 identified issues'
        ],
        'skillBoost': {for (final s in _skillsFor(5)) s: 5},
      },
      {
        'title': 'Capstone: Production-Ready Portfolio Project',
        'description':
            'Apply everything learned by building a complete, deployable $role project from scratch. Focus on production patterns, performance, accessibility, and presenting your work professionally.',
        'skills': _skillsFor(6),
        'hours': 25,
        'order': 7,
        'resources': [
          {
            'title': '$role Production Best Practices — Official Docs',
            'platform': 'official_docs',
            'search': '$role production deployment best practices official guide'
          },
          {
            'title': 'Build and Deploy $role Full Project — Traversy Media',
            'platform': 'youtube',
            'search': '$role full project build deploy tutorial Traversy Media'
          }
        ],
        'practice': [
          'Design and build a complete $role application solving a real problem',
          'Deploy to production (Play Store, App Store, Vercel, or equivalent) with a live URL',
          'Write a detailed case study README with architecture diagram, tech decisions, and demo screenshots'
        ],
        'skillBoost': {for (final s in _skillsFor(6)) s: 8},
      },
    ];

    return modules;
  }
}