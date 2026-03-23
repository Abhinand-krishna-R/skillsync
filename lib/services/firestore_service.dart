import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/skill_model.dart';
import '../models/module_model.dart';
import '../models/roles_db.dart';
import 'scoring_service.dart';
import 'ai_service.dart';
import '../theme/app_theme.dart';

/// Handles all Firestore operations for SkillSync.
class FirestoreService {
  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String? get uid => _uid;

  DocumentReference get _userDoc => _db.collection('users').doc(_uid);
  CollectionReference get _skillsCol => _userDoc.collection('skills');
  CollectionReference get _modulesCol => _userDoc.collection('modules');
  CollectionReference get _notificationsCol =>
      _userDoc.collection('notifications');
  CollectionReference get _scoreHistoryCol =>
      _userDoc.collection('scoreHistory');
  CollectionReference get _userRolesCol =>
      _userDoc.collection('userRoles');

  // ─────────────────────────────────────────────────────────────
  // STREAMS
  // ─────────────────────────────────────────────────────────────
  Stream<DocumentSnapshot> userStream(String uid) =>
      _db.collection('users').doc(uid).snapshots();

  Stream<QuerySnapshot> skillsStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('skills')
      .orderBy('name')
      .snapshots();

  Stream<QuerySnapshot> modulesStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('modules')
      .orderBy('order')
      .snapshots();

  Stream<QuerySnapshot> notificationsStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> scoreHistoryStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('scoreHistory')
      .orderBy('date')
      .snapshots();

  Stream<QuerySnapshot> userRolesStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('userRoles')
      .snapshots();

  // ─────────────────────────────────────────────────────────────
  // USER SETUP — called after registration
  // ─────────────────────────────────────────────────────────────
  Future<void> setupNewUser({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(uid);

    batch.set(
      userRef,
      {
        'uid': uid,
        'email': email,
        'name': displayName,
        'location': '',
        'education': '',
        'currentRole': '',
        'targetRoleSlug': null,
        'targetRoleLabel': null,
        'suggestedRoleSlug': null,
        'suggestedRoleLabel': null,
        'score': 0,
        'matchedSkills': [],
        'weakSkills': [],
        'missingSkills': [],
        'totalModulesCompleted': 0,
        'archivedRoadmaps': [],
        'roadmapVersion': 1,
        'onboardingComplete': false, // Will be overridden by merge if already exists
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Welcome notification
    final notifRef = userRef.collection('notifications').doc();
    batch.set(notifRef, {
      'title': 'Welcome to SkillSync!',
      'body':
          'Start by uploading your resume or adding skills manually to get your career readiness score.',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────
  // SAVE SKILLS + RECALCULATE
  // Skills are saved individually. Score is recalculated after.
  // ─────────────────────────────────────────────────────────────
  Future<void> saveSkills({
    required List<Map<String, dynamic>> skillsData,
    required String? targetRoleSlug,
  }) async {
    if (_uid == null) return;
    try {
      // 1. Get current skills to compute new score atomically
      final snap = await _skillsCol.get();
      final List<SkillModel> skills = snap.docs
          .map((d) => SkillModel.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();

      final batch = _db.batch();

      // 2. Add/Update each skill
      for (final s in skillsData) {
        final rawName = s['name'] as String? ?? '';
        if (rawName.isEmpty) continue;
        
        final normalized = RolesDB.normalizeSkill(rawName);
        if (normalized.length < 2) continue;

        final docId = normalized.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        final skillModel = SkillModel(
          id: docId,
          name: normalized,
          level: (s['level'] as int? ?? 65).clamp(1, 100),
          category: s['category'] as String? ?? 'Other',
        );

        // Update local list for accurate score calculation
        skills.removeWhere((sk) => sk.id == docId);
        skills.add(skillModel);

        batch.set(
          _skillsCol.doc(docId),
          {
            ...skillModel.toMap(),
            'source': s['source'] as String? ?? 'manual',
            'addedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // 3. Recalculate and include in THIS batch
      await _buildRecalculateOps(batch, skills, targetRoleSlug);

      // 4. Atomic commit
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.saveSkills error: $e');
      rethrow;
    }
  }


  // ─────────────────────────────────────────────────────────────
  // SAVE SKILL DOCUMENTS ONLY (no score recalculation)
  // Fallback used when the full saveSkills pipeline fails.
  // Writes only the skill documents to Firestore — score is
  // recomputed in AppState from the live stream update.
  // ─────────────────────────────────────────────────────────────
  Future<void> saveSkillDocsOnly(List<Map<String, dynamic>> skillsData) async {
    if (_uid == null) return;
    final batch = _db.batch();
    for (final s in skillsData) {
      final rawName = s['name'] as String? ?? '';
      if (rawName.isEmpty) continue;
      final normalized = RolesDB.normalizeSkill(rawName);
      if (normalized.length < 2) continue;
      final docId = normalized.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      batch.set(
        _skillsCol.doc(docId),
        {
          'name': normalized,
          'level': (s['level'] as int? ?? 65).clamp(1, 100),
          'category': s['category'] as String? ?? 'Other',
          'source': s['source'] as String? ?? 'manual',
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE SKILL
  // ─────────────────────────────────────────────────────────────
  Future<void> deleteSkill(String skillId) async {
    if (_uid == null) return;
    try {
      final snap = await _skillsCol.get();
      final List<SkillModel> skills = snap.docs
          .map((d) => SkillModel.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();

      final batch = _db.batch();
      batch.delete(_skillsCol.doc(skillId));
      
      skills.removeWhere((s) => s.id == skillId);

      final profile = await _userDoc.get();
      final targetSlug = (profile.data() as Map<String, dynamic>?)?['targetRoleSlug'] as String?;

      await _buildRecalculateOps(batch, skills, targetSlug);
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.deleteSkill error: $e');
      rethrow;
    }
  }

  /// Updates a skill level or category
  Future<void> updateSkill({
    required String skillId,
    required int level,
    required String category,
  }) async {
    if (_uid == null) return;
    try {
      final snap = await _skillsCol.get();
      final List<SkillModel> skills = snap.docs
          .map((d) => SkillModel.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();

      final batch = _db.batch();
      final updateData = {
        'level': level.clamp(1, 100),
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.update(_skillsCol.doc(skillId), updateData);
      
      final idx = skills.indexWhere((s) => s.id == skillId);
      if (idx != -1) {
        skills[idx] = SkillModel(
          id: skills[idx].id,
          name: skills[idx].name,
          level: level,
          category: category,
        );
      }

      final profile = await _userDoc.get();
      final targetSlug = (profile.data() as Map<String, dynamic>?)?['targetRoleSlug'] as String?;

      await _buildRecalculateOps(batch, skills, targetSlug);
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.updateSkill error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUBLIC RECALCULATE — called by AppState for stale data fix
  // ─────────────────────────────────────────────────────────────
  Future<void> recalculateScore(String? targetRoleSlug) async {
    await _recalculateAndSave(targetRoleSlug);
  }

  // ─────────────────────────────────────────────────────────────
  // USER ROLES — AI roles adopted by user
  // ─────────────────────────────────────────────────────────────
  Future<void> saveUserRole(CareerRole role) async {
    if (_uid == null) return;
    try {
      await _userRolesCol.doc(role.slug).set(role.toMap());
      debugPrint('FirestoreService: Saved custom user role: ${role.slug}');
    } catch (e) {
      debugPrint('FirestoreService.saveUserRole error: $e');
      rethrow;
    }
  }

  Future<void> deleteUserRole(String slug) async {
    if (_uid == null) return;
    try {
      await _userRolesCol.doc(slug).delete();
      debugPrint('FirestoreService: Deleted custom user role: $slug');
    } catch (e) {
      debugPrint('FirestoreService.deleteUserRole error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RECALCULATE SCORE + SAVE TO FIRESTORE
  // Called after any skill change. Uses RolesDB for requiredSkills.
  // ─────────────────────────────────────────────────────────────
  /// Internal method for re-usable scoring logic in batches
  Future<void> _buildRecalculateOps(WriteBatch batch, List<SkillModel> skills, String? targetRoleSlug) async {
    if (_uid == null) return;
    
    // Fetch custom roles
    final customSnap = await _userRolesCol.get();
    final customRoles = {
      for (final doc in customSnap.docs)
        doc.id: CareerRole.fromMap(doc.data() as Map<String, dynamic>)
    };
    final allRoles = {...RolesDB.roles, ...customRoles};

    // Calculate score against target role only (not all roles — avoids doc size limits).
    // Full role-match computation happens in-memory in AppState from the live skills stream.
    final role = targetRoleSlug != null ? allRoles[targetRoleSlug] : null;
    final result = role != null
        ? ScoringService.computeMatch(skills, role)
        : MatchResult(slug: '', score: 0, matchedSkills: [], weakSkills: [], missingSkills: []);

    // bestMatch is cheap — only computed if there is no target role set yet.
    final bestMatch = role == null ? ScoringService.bestMatch(skills, allRoles) : null;

    // Profile update — only scalar fields and small lists (no per-role match dump)
    batch.update(_userDoc, {
      'score': result.score,
      'matchedSkills': result.matchedSkills,
      'weakSkills': result.weakSkills,
      'missingSkills': result.missingSkills,
      'suggestedRoleSlug': bestMatch?.slug,
      'suggestedRoleLabel': bestMatch?.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Score history update (one entry per day)
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    batch.set(_scoreHistoryCol.doc(dateStr), {
      'score': result.score,
      'date': dateStr,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _recalculateAndSave(String? targetRoleSlug) async {
    if (_uid == null) return;
    try {
      final snap = await _skillsCol.get();
      final skills = snap.docs
          .map((d) => SkillModel.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();

      final batch = _db.batch();
      await _buildRecalculateOps(batch, skills, targetRoleSlug);
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService._recalculateAndSave error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SET TARGET ROLE + GENERATE ROADMAP
  // ─────────────────────────────────────────────────────────────
  Future<void> setTargetRoleAndGenerateRoadmap({
    required String slug,
    required String label,
    required List<String> userSkills,
    required List<String> missingSkills,
    bool archiveCurrent = true,
  }) async {
    if (_uid == null) return;
    try {
      final userSnap = await _userDoc.get();
      final userData = userSnap.data() as Map<String, dynamic>?;
      
      final previousRoleSlug = userData?['targetRoleSlug'] as String?;
      final previousRoleLabel = userData?['targetRoleLabel'] as String?;
      final previousCompletedModules = userData?['totalModulesCompleted'] as int? ?? 0;
      
      // Get all modules to count them (for archiving)
      final modulesSnap = await _modulesCol.get();
      final previousTotalModules = modulesSnap.size;

      final skillsSnap = await _skillsCol.get();
      final List<SkillModel> skills = skillsSnap.docs
          .map((d) => SkillModel.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();

      // Resolve role data
      final role = RolesDB.safeGet(slug) ?? await _getDynamicRoleProfile(slug, label);
      if (role == null) throw Exception('Could not resolve role details for $label');

      final match = ScoringService.computeMatch(skills, role);

      // ── Try global roadmap cache first (Versioned + Personalized Hash) ──
      final userSkillNames = skills.map((s) => s.name).toList()..sort();
      final inputSecret = '$slug|${userSkillNames.join(',')}|${match.missingSkills.join(',')}';
      final cacheHash = md5.convert(utf8.encode(inputSecret)).toString();
      final cacheCategory = 'roadmaps_v${AiService.roadmapPromptVersion}';
      
      List<Map<String, dynamic>>? modulesData;
      final cached = await getGlobalCache(cacheCategory, cacheHash);
      final cachedModules = cached != null 
          ? (cached['modules'] as List?)?.map((m) => Map<String, dynamic>.from(m as Map)).toList() 
          : null;

      if (cachedModules != null) {
        debugPrint('FirestoreService: Roadmap cache HIT for $slug ($cacheHash)');
        modulesData = cachedModules;
      } else {
        debugPrint('FirestoreService: Generating FRESH roadmap for $slug (v${AiService.roadmapPromptVersion})');
        // Pass full skill context so the prompt generates a personalised roadmap
        final skillsWithLevels = skills.map((s) => {
          'name': s.name,
          'level': s.level,
          'category': s.category,
        }).toList();

        modulesData = await AiService.generateRoadmap(
          targetRole: label,
          userSkills: userSkills,
          missingSkills: match.missingSkills,
          skillsWithLevels: skillsWithLevels,
          weakSkills: match.weakSkills,
          currentScore: match.score,
        );
        
        // Cache if successful
        if (modulesData != null && modulesData.isNotEmpty) {
          await saveGlobalCache(cacheCategory, cacheHash, {'modules': modulesData});
        }
      }

      final batch = _db.batch();

      // 1. Archive old roadmap
      if (archiveCurrent && previousRoleSlug != null && previousRoleSlug.isNotEmpty && previousRoleSlug != slug) {
        batch.update(_userDoc, {
          'archivedRoadmaps': FieldValue.arrayUnion([
            {
              'slug': previousRoleSlug,
              'label': previousRoleLabel ?? previousRoleSlug,
              'completedModules': previousCompletedModules,
              'totalModules': previousTotalModules,
              'archivedAt': DateTime.now().toIso8601String(),
            }
          ]),
        });
      }

      // 2. Update target role
      batch.update(_userDoc, {
        'targetRoleSlug': slug,
        'targetRoleLabel': label,
        'roadmapVersion': AiService.roadmapPromptVersion,
        'score': match.score,
        'matchedSkills': match.matchedSkills,
        'weakSkills': match.weakSkills,
        'missingSkills': match.missingSkills,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Delete old modules (Atomic)
      for (final doc in modulesSnap.docs) {
        batch.delete(doc.reference);
      }

      // 4. Write new modules (Atomic)
      if (modulesData != null) {
        for (final m in modulesData) {
          final order = (m['order'] as num?)?.toInt() ?? 1;
          batch.set(_modulesCol.doc(), {
            'title': m['title'] ?? 'Module $order',
            'description': m['description'] ?? '',
            'hours': (m['hours'] as num?)?.toInt() ?? 8,
            'tags': List<String>.from(m['skills'] as List? ?? []),
            'status': order == 1 ? ModuleStatus.active : ModuleStatus.locked,
            'progress': 0,
            'skillBoost': Map<String, int>.from(m['skillBoost'] ?? {}),
            'order': order,
            'resources': (m['resources'] as List<dynamic>?)
                    ?.map((r) => {
                          'title': r['title']?.toString() ?? '',
                          'platform': r['platform']?.toString() ?? 'youtube',
                          'search': (r['search'] ?? r['link_or_search'])?.toString() ?? '',
                        })
                    .toList() ??
                [],
            'practice': List<String>.from(m['practice'] as List? ?? []),
            'roadmapVersion': AiService.roadmapPromptVersion,
            'completedAt': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 5. Build Recalculate Ops (Atomic Score Update)
      await _buildRecalculateOps(batch, skills, slug);

      await batch.commit();

      // Add notification
      await _notificationsCol.add({
        'title': 'Roadmap ready!',
        'body': 'Your personalised learning path to $label is ready.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'icon': 'target',
        'colorValue': AppColors.neon.value,
      });
    } catch (e) {
      debugPrint('FirestoreService.setTargetRoleAndGenerateRoadmap error: $e');
      rethrow;
    }
  }


  // ─────────────────────────────────────────────────────────────
  // COMPLETE A MODULE
  // ─────────────────────────────────────────────────────────────
  Future<void> completeModule({
    required String moduleId,
    required String? targetRoleSlug,
    String? nextModuleId, // resolved in AppState from in-memory list — no Firestore query needed
  }) async {
    if (_uid == null) return;
    try {
      // 1. Fetch module to get skillBoost
      final modSnap = await _modulesCol.doc(moduleId).get();
      if (!modSnap.exists) return;
      final modData = modSnap.data() as Map<String, dynamic>;
      final skillBoost = Map<String, int>.from(modData['skillBoost'] ?? {});

      final batch = _db.batch();

      // 2. Mark module completed
      batch.update(_modulesCol.doc(moduleId), {
        'status': ModuleStatus.completed,
        'progress': 100,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 3. Apply skill boosts to existing skills
      if (skillBoost.isNotEmpty) {
        final skillsSnap = await _skillsCol.get();
        for (final doc in skillsSnap.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          final skillName = data?['name'] as String?;
          if (skillName != null && skillBoost.containsKey(skillName)) {
            final currentLevel = (data?['level'] as num?)?.toInt() ?? 65;
            final boost = skillBoost[skillName] ?? 0;
            batch.update(doc.reference, {
              'level': (currentLevel + boost).clamp(1, 100),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // 4. Unlock next module — ID resolved in AppState from in-memory list,
      //    so no Firestore index or extra query is needed here.
      if (nextModuleId != null) {
        batch.update(
            _modulesCol.doc(nextModuleId), {'status': ModuleStatus.active});
      }

      // 5. Increment completed count in profile
      batch.update(_userDoc, {
        'totalModulesCompleted': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Recalculate score with real required skills
      await _recalculateAndSave(targetRoleSlug);

      // Completion notification
      await _notificationsCol.add({
        'title': 'Module complete!',
        'body': 'Great work! Keep going to unlock the next module.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.completeModule error: $e');
      rethrow;
    }
  }

  /// Updates the checklist state for a module
  Future<void> updateModuleTasks({
    required String moduleId,
    required List<bool> tasks,
  }) async {
    if (_uid == null) return;
    try {
      await _modulesCol.doc(moduleId).update({
        'tasks': tasks,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.updateModuleTasks error: $e');
      rethrow;
    }
  }

  /// Clears the user's targeted role, returning them to exploration mode
  Future<void> clearTargetRoleAndModules() async {
    if (_uid == null) return;
    try {
      final batch = _db.batch();

      // 1. Clear profile fields
      batch.update(_userDoc, {
        'targetRoleSlug': null,
        'targetRoleLabel': null,
        'roadmapVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Delete all modules
      final snapshot = await _modulesCol.get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('FirestoreService: Target role and modules cleared');
    } catch (e) {
      debugPrint('FirestoreService.clearTargetRoleAndModules error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GENERIC AI CACHING (Global & User-Specific)
  // ─────────────────────────────────────────────────────────────

  /// USER-LEVEL CACHE: users/{uid}/aiCache_{collection}/{id}
  Future<Map<String, dynamic>?> getAiCache(String collection, String id) async {
    if (_uid == null) return null;
    try {
      final snap =
          await _userDoc.collection('aiCache_$collection').doc(id).get();
      if (!snap.exists) return null;

      final data = snap.data() as Map<String, dynamic>?;
      // Expire cache after 7 days
      final ts = data?['timestamp'] as Timestamp?;
      if (ts != null) {
        final age = DateTime.now().difference(ts.toDate());
        if (age.inDays > 7) return null;
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveAiCache(
      String collection, String id, Map<String, dynamic> data) async {
    if (_uid == null) return;
    try {
      await _userDoc.collection('aiCache_$collection').doc(id).set({
        ...data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.saveAiCache error: $e');
    }
  }

  /// GLOBAL-LEVEL CACHE: aiCache/{category}/entries/{id}
  Future<Map<String, dynamic>?> getGlobalCache(
      String category, String id) async {
    try {
      final doc = await _db
          .collection('aiCache')
          .doc(category)
          .collection('entries')
          .doc(id)
          .get();
      if (!doc.exists) return null;
      
      final data = doc.data();
      // Expire cache after 7 days
      final ts = data?['cachedAt'] as Timestamp?;
      if (ts != null) {
        final age = DateTime.now().difference(ts.toDate());
        if (age.inDays > 7) return null;
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveGlobalCache(
      String category, String id, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('aiCache')
          .doc(category)
          .collection('entries')
          .doc(id)
          .set({
        ...data,
        'cachedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.saveGlobalCache error: $e');
    }
  }
  // ─────────────────────────────────────────────────────────────
  // PROFILE UPDATE
  // ─────────────────────────────────────────────────────────────
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────
  Future<void> markNotifRead(String id) async {
    if (_uid == null) return;
    await _notificationsCol.doc(id).update({'read': true});
  }

  Future<void> markAllNotificationsRead() async {
    if (_uid == null) return;
    final snap = await _notificationsCol
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────
  // SCORE HISTORY — fetch last 7 days
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getScoreHistory() async {
    if (_uid == null) return [];
    try {
      final snap = await _scoreHistoryCol
          .orderBy('date', descending: false)
          .limitToLast(7)
          .get();
      return snap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('FirestoreService.getScoreHistory error: $e');
      return [];
    }
  }

  Future<void> deleteUserAccount() async {
    if (_uid == null) return;
    try {
      await _db.collection('users').doc(_uid).delete();
    } catch (e) {
      debugPrint('FirestoreService.deleteUserAccount error: $e');
      rethrow;
    }
  }
  Future<CareerRole?> _getDynamicRoleProfile(String slug, String label) async {
    try {
      final profile = await AiService.generateRoleProfile(label);
      if (profile == null) return null;
      return CareerRole(
        slug: slug,
        name: profile['title'] ?? label,
        description: profile['description'] ?? '',
        category: profile['category'] ?? 'Career',
        demand: profile['demand'] ?? 'Medium',
        salary: profile['salary'] ?? '',
        icon: profile['icon'] ?? 'work_outline',
        requiredSkills: List<String>.from(profile['requiredSkills'] ?? []),
        weights: (profile['weights'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        requiredLevels: (profile['requiredLevels'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        tools: List<String>.from(profile['tools'] ?? []),
        aiTips: List<String>.from(profile['aiTips'] ?? []),
        color: AppColors.neon2,
        qualificationRequired: profile['qualificationRequired'] ?? false,
        qualifications: List<String>.from(profile['qualifications'] ?? []),
        qualificationNote: profile['qualificationNote'] ?? '',
      );
    } catch (e) {
      debugPrint('FirestoreService._getDynamicRoleProfile error: $e');
      return null;
    }
  }
}