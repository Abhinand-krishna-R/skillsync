import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';
import 'auth_state.dart';
import 'skill_model.dart';
import 'profile_model.dart';
import 'module_model.dart';
import 'notification_model.dart';
import 'roles_db.dart';
import '../services/scoring_service.dart';
import '../theme/app_theme.dart';

class AppState extends ChangeNotifier {
  final firestoreService = FirestoreService();
  AuthState? _auth;

  void attachAuthState(AuthState auth) {
    _auth = auth;
  }

  /// Entry point for AuthState to notify AppState about login/logout.
  /// Handles stream lifecycle and data cleanup.
  Future<void> onAuthChanged(String? uid) async {
    if (uid != null) {
      await _subscribeToUserData(uid);
    } else {
      _cancelUserDataSubscriptions();
      _clearLocalState();
    }
    notifyListeners();
  }

  // Delegate auth properties to AuthState
  User? get firebaseUser => _auth?.firebaseUser;
  bool get authLoading => _auth?.authLoading ?? true;
  String? get uid => _auth?.uid;
  bool get isLoggedIn => _auth?.isLoggedIn ?? false;
  UserProfile? profile;
  bool _profileInitialized = false;
  bool get profileInitialized => _profileInitialized;

  List<SkillModel> skills = [];
  List<ModuleModel> modules = [];
  Map<String, CareerRole> _customRoles = {};
  Map<String, CareerRole> _dynamicRoleCache = {};
  List<NotificationModel> notifications = [];
  List<Map<String, dynamic>> scoreHistory = [];
  int _cachedScore = 0;
  Map<String, List<String>> _cachedGapAnalysis = {
    'matched': [],
    'weak': [],
    'missing': []
  };

  // ── UI state ───────────────────────────────────────────────────
  bool _loadingRoadmap = false;
  bool get loadingRoadmap => _loadingRoadmap;
  String? _roadmapError;
  String? get roadmapError => _roadmapError;
  String? _lastSuggestionHash;
  void clearRoadmapError() {
    _roadmapError = null;
    notifyListeners();
  }
  // Task progress is stored per-module in Firestore and hydrated via ModuleModel.tasks.
  List<bool> getModuleTasks(String moduleId, int count) {
    final module = modules.where((m) => m.id == moduleId).firstOrNull;
    if (module != null && module.tasks.length == count) {
      return module.tasks;
    }
    return List.generate(count, (_) => false);
  }
  void setModuleTask(String moduleId, int index, bool value) async {
    final moduleIndex = modules.indexWhere((m) => m.id == moduleId);
    if (moduleIndex != -1) {
      final currentTasks = List<bool>.from(getModuleTasks(moduleId, modules[moduleIndex].practice.length));
      currentTasks[index] = value;
      
      // Update local state first for responsiveness
      modules[moduleIndex] = modules[moduleIndex].copyWith(tasks: currentTasks);
      notifyListeners();

      // Sync to Firestore
      try {
        await firestoreService.updateModuleTasks(
          moduleId: moduleId,
          tasks: currentTasks,
        );
      } catch (e) {
        debugPrint('AppState.setModuleTask sync error: $e');
      }
    }
  }

  // resume logic moved to UiState

  // ── Stream subscriptions ───────────────────────────────────────
  // NOTE: _authSub lives in AuthState — not here — so it is never
  // accidentally cancelled during sign-out. Only user-data streams
  // are managed below.
  StreamSubscription? _profileSub,
      _skillsSub,
      _modulesSub,
      _userRolesSub,
      _notifsSub;

  AppState() {
    // Subscriptions now handled via onAuthChanged.
    // _clearLocalState() is called here to ensure a clean state on app start.
    _clearLocalState();
  }

  // ── Computed getters ───────────────────────────────────────────
  // Deleted old auth getters — now delegated via _auth
  int get unreadCount => notifications.where((n) => !n.read).length;

  int get score => _cachedScore;

  // ── Role Matching Memoization (P1 Performance) ──
  Map<String, MatchResult> _roleMatches = {};
  bool _matchesDirty = true;

  Map<String, MatchResult> get roleMatches {
    if (_matchesDirty) {
      _roleMatches = ScoringService.computeRoleMatches(skills, allRoles);
      _matchesDirty = false;
    }
    return _roleMatches;
  }

  void _recomputeReadiness() {
    // Mark matches as dirty so they recompute on next access
    _matchesDirty = true;
    
    // Guard against empty roles data
    if (RolesDB.roles.isEmpty) {
      _cachedScore = 0;
      _cachedGapAnalysis = {'matched': [], 'weak': [], 'missing': []};
      notifyListeners();
      return;
    }

    final p = profile;
    if (p == null) return;

    final targetSlug = p.targetRoleSlug;
    CareerRole? role;

    if (targetSlug != null) {
      role = allRoles[targetSlug] ?? getDynamicRole(targetSlug);
    } else {
      // Suggestion Threshold: Only pick best match if score >= 25%
      final best = ScoringService.bestMatch(skills, allRoles);
      if (best != null) {
        final res = ScoringService.computeMatch(skills, best);
        if (res.score >= 25) {
          role = best;
        }
      }
    }

    if (role != null) {
      final result = ScoringService.computeMatch(skills, role);
      _cachedScore = result.score;
      _cachedGapAnalysis = {
        'matched': result.matchedSkills,
        'weak': result.weakSkills,
        'missing': result.missingSkills,
      };
    } else {
      _cachedScore = 0;
      _cachedGapAnalysis = {'matched': [], 'weak': [], 'missing': []};
    }
    notifyListeners();
  }

  Map<String, List<String>> get gapAnalysis => _cachedGapAnalysis;

  /// Formats a role slug (e.g. data_scientist) into a readable title (e.g. Data Scientist).
  String _formatRole(String slug) {
    return slug
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? (w[0].toUpperCase() + w.substring(1)) : '')
        .join(' ');
  }

  /// Generates a personalized career insight based on current profile and matches.
  /// All data (role title, score, missing skills) is derived from ONE consistent
  /// role to prevent mismatched insight sentences.
  String generateInsight() {
    if (skills.isEmpty) {
      return "Add skills to discover your career readiness.";
    }

    if (roleMatches.isEmpty) {
      return "Exploring career matches...";
    }

    // Resolve a single reference role — target if set, otherwise best match.
    final targetSlug = profile?.targetRoleSlug;
    String? referenceSlug;
    MatchResult? referenceMatch;

    if (targetSlug != null && roleMatches.containsKey(targetSlug)) {
      referenceSlug = targetSlug;
      referenceMatch = roleMatches[targetSlug];
    } else {
      final sorted = roleMatches.entries.toList()
        ..sort((a, b) => b.value.score.compareTo(a.value.score));
      if (sorted.isNotEmpty) {
        referenceSlug = sorted.first.key;
        referenceMatch = sorted.first.value;
      }
    }

    if (referenceSlug == null || referenceMatch == null) {
      return "Learning more skills will help us find your best career matches.";
    }

    // Threshold check for insight stability
    if (referenceMatch.score < 25) {
      return "Learning more skills will help us find your best career matches.";
    }

    final roleTitle = profile?.targetRoleLabel ?? _formatRole(referenceSlug);

    // Use missing skills from the SAME reference role — not from _cachedGapAnalysis
    // which may be scoped to a different role.
    final role = allRoles[referenceSlug] ?? getDynamicRole(referenceSlug);
    final missing = role != null
        ? ScoringService.computeMatch(skills, role).missingSkills
        : <String>[];

    if (missing.isNotEmpty) {
      return "You are closest to becoming a $roleTitle. Learning ${missing.first} would improve your match.";
    }

    if (referenceMatch.score >= 80) {
      return "You are highly matched for $roleTitle. Consider applying now!";
    }

    final topSkill = skills.reduce((a, b) => a.level > b.level ? a : b);
    return "Your strongest skill is ${topSkill.name}. Keep building towards $roleTitle!";
  }

  Future<Map<String, dynamic>> semanticGapAnalysis({
    required String roleSlug,
    required List<String> roleSkills,
  }) async {
    final userSkillNames = skills.map((s) => s.name).toList();
    final skillsHash = AiService.hashSkills(userSkillNames);
    final cacheId = '${roleSlug}_$skillsHash';

    // 1. Local Database Match (Always First, Zero Latency)
    if (RolesDB.roles.containsKey(roleSlug)) {
      final role = RolesDB.roles[roleSlug]!;
      final result = ScoringService.computeMatch(skills, role);
      return {
        'match': result.matchedSkills,
        'weak': result.weakSkills,
        'missing': result.missingSkills,
        'score': result.score,
        'source': 'local',
      };
    }

    // 2. Persistent Firestore Cache
    final cached = await firestoreService.getAiCache('semanticGap', cacheId);
    if (cached != null) {
      return {...cached, 'source': 'cache'};
    }

    // 3. AI Generation
    final result = await AiService.semanticGapAnalysis(
      userSkills: userSkillNames,
      roleSkills: roleSkills,
    );
    
    // Save to cache for next time
    await firestoreService.saveAiCache('semanticGap', cacheId, result);
    return {...result, 'source': 'ai'};
  }

  bool _loadingInsights = false;
  String? _lastInsightRole;
  Future<Map<String, dynamic>> generateInterviewInsights(String roleName) async {
    final roleSlug = RolesDB.slugify(roleName);
    
    // Guard: Don't load if already loading OR already showing insights for this same role
    if (_loadingInsights || _lastInsightRole == roleSlug) {
       debugPrint('AppState: Insight guard triggered for $roleSlug (loading: $_loadingInsights)');
       return {'source': 'memory'}; 
    }

    _loadingInsights = true;
    notifyListeners();

    try {
      // 1. Persistent Firestore Cache
      final cached = await firestoreService.getAiCache('interviewInsights', roleSlug);
      if (cached != null) {
        _lastInsightRole = roleSlug;
        return {...cached, 'source': 'cache'};
      }

      // 2. AI Generation — pass skill context for personalised questions and tips
      final result = await AiService.generateInterviewInsights(
        roleName,
        userSkills: skills.map((s) => s.name).toList(),
        matchedSkills: gapAnalysis['matched'] ?? [],
        missingSkills: gapAnalysis['missing'] ?? [],
      );
      
      // Save to cache
      await firestoreService.saveAiCache('interviewInsights', roleSlug, result);
      _lastInsightRole = roleSlug;
      return {...result, 'source': 'ai'};
    } finally {
      _loadingInsights = false;
      notifyListeners();
    }
  }

  ModuleModel? get activeModule =>
      modules.where((m) => m.isActive).isNotEmpty
          ? modules.firstWhere((m) => m.isActive)
          : null;
  bool get hasActiveModule => modules.any((m) => m.isActive);

  int get completedModulesCount => modules.where((m) => m.isCompleted).length;

  /// Merged pool of system roles + user-adopted AI roles
  Map<String, CareerRole> get allRoles => {
    ...RolesDB.roles,
    ..._customRoles,
  };


  CareerRole? getDynamicRole(String slug) {
    return allRoles[slug] ?? _dynamicRoleCache[slug];
  }

  bool _fetchingSuggestions = false;

  Future<void> fetchDynamicRoleSuggestions({bool force = false}) async {
    if (skills.isEmpty ||
        _fetchingSuggestions ||
        firestoreService.uid == null) {
      return;
    }

    final userSkillNames = skills.map((s) => s.name).toList()..sort();
    final skillsHash = AiService.hashSkills(userSkillNames);
    
    // Throttling: Don't refetch if the skill hash hasn't changed (unless forced)
    if (!force && skillsHash == _lastSuggestionHash) return;
    _lastSuggestionHash = skillsHash;

    _fetchingSuggestions = true;
    try {
      final cached = await firestoreService.getAiCache('roleSuggestions', skillsHash);
      if (cached != null) {
        final roles = (cached['roles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _dynamicRoleCache.clear();
        for (final s in roles) {
          final role = _createCareerRoleFromSuggestion(s);
          _dynamicRoleCache[role.slug] = role;
        }
        notifyListeners();
        return;
      }

      final suggestions =
          await AiService.generateRoleSuggestions(userSkillNames);
      if (suggestions.isNotEmpty) {
        _dynamicRoleCache.clear();
        for (final s in suggestions) {
          final role = _createCareerRoleFromSuggestion(s);
          _dynamicRoleCache[role.slug] = role;
        }
        await firestoreService.saveAiCache('roleSuggestions', skillsHash, {'roles': suggestions});
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AppState.fetchDynamicRoleSuggestions error: $e');
    } finally {
      _fetchingSuggestions = false;
      notifyListeners();
    }
  }

  CareerRole _createCareerRoleFromSuggestion(Map<String, dynamic> suggest) {
    final slug = suggest['slug'] as String? ?? RolesDB.slugify(suggest['title'] ?? '');
    final name = suggest['title']?.toString() ??
        slug
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');

    final rawSkills = (suggest['requiredSkills'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final requiredSkills = rawSkills.map((s) => RolesDB.normalizeSkill(s)).toList();

    // Parse AI-generated weights — handle String, int, double
    final Map<String, dynamic> rawWeights = suggest['weights'] is Map ? Map<String, dynamic>.from(suggest['weights'] as Map) : {};
    final Map<String, double> weights = {};
    
    for (var skill in requiredSkills) {
      final rawV = rawWeights[skill] ?? rawWeights[RolesDB.normalizeSkill(skill)] ?? 1.0;
      double val = 1.0;
      if (rawV is num) {
        val = rawV.toDouble();
      } else if (rawV is String) {
        val = double.tryParse(rawV) ?? 1.0;
      }
      weights[skill] = val;
    }

    // Parse AI-generated requiredLevels — handle String, int, double
    final Map<String, dynamic> rawLevels = suggest['requiredLevels'] is Map ? Map<String, dynamic>.from(suggest['requiredLevels'] as Map) : {};
    final Map<String, int> requiredLevels = {};

    for (var skill in requiredSkills) {
      final rawV = rawLevels[skill] ?? rawLevels[RolesDB.normalizeSkill(skill)] ?? 75;
      int val = 75;
      if (rawV is num) {
        val = rawV.toInt();
      } else if (rawV is String) {
        val = int.tryParse(rawV) ?? 75;
      }
      requiredLevels[skill] = val;
    }

    return CareerRole(
      slug: slug,
      name: name,
      description:
          suggest['description']?.toString() ?? 'AI Suggested Role based on your skills.',
      category: suggest['category']?.toString() ?? 'Dynamic',
      demand: suggest['demand']?.toString() ?? 'High',
      salary: suggest['salary']?.toString() ?? 'Varies',
      icon: 'auto_awesome',
      color: AppColors.neon2,
      requiredSkills: requiredSkills,
      weights: weights,
      requiredLevels: requiredLevels,
      tools: (suggest['tools'] as List?)?.map((e) => e.toString()).toList() ?? [],
      aiTips: (suggest['aiTips'] as List?)?.map((e) => e.toString()).toList() ??
          [suggest['description']?.toString() ?? 'This role matches your profile.'],
      qualificationRequired: suggest['qualificationRequired'] == true || suggest['qualificationRequired'] == 'true',
      qualifications: (suggest['qualifications'] as List?)?.whereType<String>().toList() ?? [],
      qualificationNote: suggest['qualificationNote']?.toString() ?? '',
      source: suggest['source']?.toString() ?? 'ai',
      careerCluster: suggest['careerCluster']?.toString() ?? 'AI Generated',
      createdAt: suggest['createdAt'] != null ? DateTime.tryParse(suggest['createdAt'].toString()) : DateTime.now(),
      difficulty: double.tryParse(suggest['difficulty']?.toString() ?? '1.2') ?? 1.2,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SUBSCRIPTIONS
  // ─────────────────────────────────────────────────────────────
  Future<void> _subscribeToUserData(String uid) async {
    _cancelUserDataSubscriptions();

    _profileSub = firestoreService.userStream(uid).listen(
      (snap) {
        if (snap.exists) {
          profile = UserProfile.fromMap(snap.data() as Map<String, dynamic>);
        } else {
          profile = null;
        }
        _profileInitialized = true;
        // Always call _recomputeReadiness so notifyListeners() fires
        // regardless of snap.exists — unblocks the profile loading spinner.
        _recomputeReadiness();
      },
      onError: (e) {
        debugPrint('AppState: profile stream error: $e');
        notifyListeners(); // unblock UI waiting on profile != null
      },
    );

    _skillsSub = firestoreService.skillsStream(uid).listen(
      (snap) {
        final serverSkills = snap.docs
            .map((doc) =>
                SkillModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();
        
        // MERGE LOGIC: Keep temp skills that haven't been confirmed by the server yet
        final List<SkillModel> merged = [...serverSkills];
        final tempSkills = skills.where((s) => s.id.startsWith('temp_')).toList();
        
        for (final temp in tempSkills) {
          // If server already has this skill (normalized match), we can discard the temp one
          final confirmed = serverSkills.any((s) => RolesDB.isMatch(s.name, temp.name));
          if (!confirmed) {
            merged.add(temp);
          }
        }
        
        skills = merged;
        _recomputeReadiness();
        if (skills.isNotEmpty) {
          fetchDynamicRoleSuggestions();
        }
      },
      onError: (e) {
        debugPrint('AppState: skills stream error: $e');
        notifyListeners();
      },
    );

    _modulesSub = firestoreService.modulesStream(uid).listen(
      (snap) {
        modules = snap.docs
            .map((doc) =>
                ModuleModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('AppState: modules stream error: $e');
        notifyListeners();
      },
    );

    _userRolesSub = firestoreService.userRolesStream(uid).listen(
      (snap) {
        _customRoles = {
          for (final doc in snap.docs)
            doc.id: CareerRole.fromMap(doc.data() as Map<String, dynamic>)
        };
        _recomputeReadiness();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('AppState: userRoles stream error: $e');
      },
    );

    _notifsSub = firestoreService.notificationsStream(uid).listen(
      (snap) {
        notifications = snap.docs
            .map((doc) => NotificationModel.fromMap(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('AppState: notifications stream error: $e');
        notifyListeners();
      },
    );

    _loadScoreHistory();
  }

  Future<void> _loadScoreHistory() async {
    scoreHistory = await firestoreService.getScoreHistory();
    notifyListeners();
  }


  // FIX: Renamed from _cancelSubscriptions to make the intent explicit.
  // This ONLY cancels user data streams. The _authSub is NEVER cancelled
  // here — it must stay alive for the entire app lifetime.
  void _cancelUserDataSubscriptions() {
    _profileSub?.cancel();
    _skillsSub?.cancel();
    _modulesSub?.cancel();
    _userRolesSub?.cancel();
    _notifsSub?.cancel();
    _profileSub = null;
    _skillsSub = null;
    _modulesSub = null;
    _userRolesSub = null;
    _notifsSub = null;
  }

  void _clearLocalState() {
    profile = null;
    skills = [];
    modules = [];
    notifications = [];
    scoreHistory = [];
    _customRoles = {};
    _dynamicRoleCache = {};
    _cachedScore = 0;
    _cachedGapAnalysis = {'matched': [], 'weak': [], 'missing': []};
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // AUTH ACTIONS
  // ─────────────────────────────────────────────────────────────

  // Moved to AuthState

  // ─────────────────────────────────────────────────────────────
  // SKILL ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> addSkill(String name, int level,
      {String category = 'Other'}) async {
    if (uid == null) return;
    
    // 1. Normalize and Check Duplicates (Optimistic)
    final normalized = RolesDB.normalizeSkill(name);
    final exists = skills.any((s) => RolesDB.isMatch(s.name, normalized));
    if (exists) return;

    final previousSkills = List<SkillModel>.from(skills);

    // 2. Optimistic local update
    final tempSkill = SkillModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}', 
      name: normalized, 
      level: level, 
      category: category
    );
    
    skills = [...skills, tempSkill];
    _recomputeReadiness();
    notifyListeners();

    // 3. Sync to Firestore — same two-step fallback as addSkillsBatch
    final singleBatch = [
      {'name': normalized, 'level': level, 'category': category, 'source': 'manual'},
    ];
    try {
      await firestoreService.saveSkills(
        skillsData: singleBatch,
        targetRoleSlug: profile?.targetRoleSlug,
      );
    } catch (fullSaveError) {
      debugPrint('AppState.addSkill: full save failed ($fullSaveError). Trying skill-docs-only fallback…');
      try {
        await firestoreService.saveSkillDocsOnly(singleBatch);
        firestoreService.recalculateScore(profile?.targetRoleSlug).catchError(
          (e) => debugPrint('AppState: async score recalc failed (non-fatal): $e'),
        );
      } catch (fallbackError) {
        debugPrint('AppState.addSkill: fallback also failed ($fallbackError). Rolling back.');
        skills = previousSkills;
        _recomputeReadiness();
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> updateSkill({
    required String skillId,
    required int level,
    required String category,
  }) async {
    try {
      await firestoreService.updateSkill(
        skillId: skillId,
        level: level,
        category: category,
      );
    } catch (e) {
      debugPrint('AppState.updateSkill error: $e');
      rethrow;
    }
  }

  Future<void> addSkillsBatch(List<Map<String, dynamic>> skillsData) async {
    if (uid == null) return;

    final previousSkills = List<SkillModel>.from(skills);

    // 1. Filter, Normalize and De-duplicate (Optimistic)
    final List<SkillModel> newSkills = [];
    final List<Map<String, dynamic>> syncBatch = [];

    for (final s in skillsData) {
      final name = s['name'] as String? ?? '';
      if (name.isEmpty) continue;
      
      final normalized = RolesDB.normalizeSkill(name);
      final alreadyPresent = skills.any((sk) => RolesDB.isMatch(sk.name, normalized)) || 
                             newSkills.any((sk) => RolesDB.isMatch(sk.name, normalized));
      
      if (!alreadyPresent) {
        newSkills.add(SkillModel(
          id: 'temp_batch_${DateTime.now().millisecondsSinceEpoch}_${newSkills.length}',
          name: normalized,
          level: (s['level'] as int? ?? 65),
          category: s['category'] as String? ?? 'Other',
        ));
        syncBatch.add({
          ...s,
          'name': normalized,
        });
      }
    }

    if (syncBatch.isEmpty) return;

    // 2. Optimistic local update
    skills = [...skills, ...newSkills];
    _recomputeReadiness();
    notifyListeners();

    // 3. Sync to Firestore
    // Strategy: try full pipeline (skill write + score recalc in one batch).
    // If it fails (e.g., Firestore rules don't cover aiResults/scoreHistory),
    // fall back to skill-docs-only write. Score is still updated locally by
    // _recomputeReadiness() and will resync via the Firestore stream.
    // Only rollback if BOTH attempts fail.
    try {
      await firestoreService.saveSkills(
        skillsData: syncBatch,
        targetRoleSlug: profile?.targetRoleSlug,
      );
    } catch (fullSaveError) {
      debugPrint('AppState.addSkillsBatch: full save failed ($fullSaveError). Trying skill-docs-only fallback…');
      try {
        await firestoreService.saveSkillDocsOnly(syncBatch);
        // Docs saved — trigger async score sync (non-blocking, can fail silently)
        firestoreService.recalculateScore(profile?.targetRoleSlug).catchError(
          (e) => debugPrint('AppState: async score recalc failed (non-fatal): $e'),
        );
        debugPrint('AppState.addSkillsBatch: skill-docs-only fallback succeeded.');
      } catch (fallbackError) {
        debugPrint('AppState.addSkillsBatch: fallback also failed ($fallbackError). Rolling back.');
        skills = previousSkills;
        _recomputeReadiness();
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> deleteSkill(String skillId) async {
    if (uid == null) return;

    // Optimistic local update — mirrors addSkill() pattern.
    // Remove immediately so Home + Analyze screens react without
    // waiting for the Firestore stream round-trip.
    final previousSkills = List<SkillModel>.from(skills);
    skills = skills.where((s) => s.id != skillId).toList();
    _recomputeReadiness();
    notifyListeners();

    try {
      await firestoreService.deleteSkill(skillId);
    } catch (e) {
      // Rollback on failure
      debugPrint('AppState.deleteSkill error: $e — rolling back');
      skills = previousSkills;
      _recomputeReadiness();
      notifyListeners();
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RESUME UPLOAD
  // ─────────────────────────────────────────────────────────────
  // Moved to UiState

  // ─────────────────────────────────────────────────────────────
  // PROFILE ACTIONS
  // ─────────────────────────────────────────────────────────────
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    if (uid == null) {
      return;
    }
    if (profile != null) {
      // Use copyWith to maintain immutable update semantics and ensure
      // all listeners receive a properly diffed state object.
      profile = profile!.copyWith(
        name: fields['name'] as String?,
        location: fields['location'] as String?,
        education: fields['education'] as String?,
        currentRole: fields['currentRole'] as String?,
      );
      notifyListeners();
    }
    await firestoreService.updateProfile(uid!, fields);
  }

  String? _roadmapLoadingSlug;
  Future<void> setTargetRole(String slug, String label, {bool archiveCurrent = true}) async {
    if (uid == null) return;
    if (_roadmapLoadingSlug == slug) {
      debugPrint('AppState: Roadmap load guard triggered for $slug');
      return;
    }

    try {
      _loadingRoadmap = true;
      _roadmapLoadingSlug = slug;
      notifyListeners();

      CareerRole? role = allRoles[slug];

      // If role is dynamic/AI search result, save it to persistent User Roles first
      if (role == null && _dynamicRoleCache.containsKey(slug)) {
        role = _dynamicRoleCache[slug];
        if (role != null) {
          final adoptedRole = CareerRole(
            slug: role.slug,
            name: role.name,
            description: role.description,
            category: role.category,
            demand: role.demand,
            salary: role.salary,
            icon: role.icon,
            color: role.color,
            requiredSkills: role.requiredSkills,
            weights: role.weights,
            requiredLevels: role.requiredLevels,
            tools: role.tools,
            aiTips: role.aiTips,
            qualificationRequired: role.qualificationRequired,
            qualifications: role.qualifications,
            qualificationNote: role.qualificationNote,
            source: 'ai',
            createdAt: DateTime.now(),
            difficulty: role.difficulty,
          );
          await firestoreService.saveUserRole(adoptedRole);
          _customRoles[slug] = adoptedRole;
          role = adoptedRole;
        }
      }
      _roadmapError = null;
      notifyListeners();

      await firestoreService.setTargetRoleAndGenerateRoadmap(
        slug: slug,
        label: label,
        userSkills: skills.map((s) => s.name).toList(),
        missingSkills: gapAnalysis['missing'] ?? [],
        archiveCurrent: archiveCurrent,
      );
    } catch (e) {
      _roadmapError = e.toString();
      debugPrint('AppState.setTargetRole error: $e');
    } finally {
      _loadingRoadmap = false;
      _roadmapLoadingSlug = null;
      notifyListeners();
    }
  }

  Future<void> clearTargetRole() async {
    if (uid == null) {
      return;
    }
    await firestoreService.clearTargetRoleAndModules();
  }

  // ─────────────────────────────────────────────────────────────
  // MODULE ACTIONS
  // ─────────────────────────────────────────────────────────────
  Future<void> completeModule(String moduleId) async {
    if (uid == null) {
      return;
    }
    final module = modules.where((m) => m.id == moduleId).firstOrNull;
    if (module == null) {
      return;
    }

    final nextModule = modules
        .where((m) => m.order == module.order + 1)
        .cast<ModuleModel?>()
        .firstWhere((_) => true, orElse: () => null);

    await firestoreService.completeModule(
      moduleId: moduleId,
      targetRoleSlug: profile?.targetRoleSlug,
      nextModuleId: nextModule?.id,
    );
    await _loadScoreHistory();
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICATION ACTIONS
  // ─────────────────────────────────────────────────────────────
  Future<void> markNotifRead(String id) async {
    if (uid == null) {
      return;
    }
    await firestoreService.markNotifRead(id);
  }

  Future<void> markAllRead() async {
    if (uid == null) {
      return;
    }
    await firestoreService.markAllNotificationsRead();
  }

  // ─────────────────────────────────────────────────────────────
  // ROLE SEARCH
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> searchRole(String roleName) async {
    if (roleName.trim().isEmpty) {
      return null;
    }

    final normalized = roleName.trim().split(' ').map((w) {
      if (w.isEmpty) {
        return w;
      }
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    final slug = RolesDB.slugify(normalized);

    // Check Global Firestore Cache first (Category: roleProfile as per spec)
    final cached = await firestoreService.getGlobalCache('roleProfile', slug);
    if (cached != null) {
      return {...cached, 'slug': slug, 'source': 'cache'};
    }

    // Always call AI for unknown roles
    final generated = await AiService.generateRoleProfile(normalized);
    if (generated != null) {
      final roleData = {
        ...generated,
        'slug': slug,
        'source': 'ai',
      };
      // Adoption Flow: Populate cache so it can be targeted & saved
      _dynamicRoleCache[slug] = _createCareerRoleFromSuggestion(roleData);
      // Also save to global role search cache
      await firestoreService.saveGlobalCache('roleProfile', slug, roleData);
      return roleData;
    }
    return null;
  }

  // UI Nav helpers moved to UiState

  @override
  void dispose() {
    // Only cancel user data subscriptions here.
    // AuthState owns and manages the auth subscription independently.
    _cancelUserDataSubscriptions();
    super.dispose();
  }
  // Moved to AuthState

  Future<void> completeOnboarding() async {
    await updateProfile({'onboardingComplete': true});
  }
}
