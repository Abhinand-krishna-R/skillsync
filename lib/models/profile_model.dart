import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  String name;
  String email;
  String location;
  String education;
  String currentRole;
  String? targetRoleSlug;
  String? targetRoleLabel;
  String? suggestedRoleSlug;
  String? suggestedRoleLabel;
  String? resumeUrl;
  final DateTime createdAt;
  DateTime updatedAt;

  int score;
  List<String> matchedSkills;
  List<String> weakSkills;
  List<String> missingSkills;

  // Archived roadmaps: list of {slug, label, completedModules, totalModules}
  List<Map<String, dynamic>> archivedRoadmaps;

  bool onboardingComplete;
  int roadmapVersion;

  UserProfile({
    required this.uid,
    this.name = '',
    this.email = '',
    this.location = '',
    this.education = '',
    this.currentRole = '',
    this.targetRoleSlug,
    this.targetRoleLabel,
    this.suggestedRoleSlug,
    this.suggestedRoleLabel,
    this.resumeUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.score = 0,
    List<String>? matchedSkills,
    List<String>? weakSkills,
    List<String>? missingSkills,
    List<Map<String, dynamic>>? archivedRoadmaps,
    this.onboardingComplete = false,
    this.roadmapVersion = 1,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        matchedSkills = matchedSkills ?? [],
        weakSkills = weakSkills ?? [],
        missingSkills = missingSkills ?? [],
        archivedRoadmaps = archivedRoadmaps ?? [];

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'location': location,
        'education': education,
        'currentRole': currentRole,
        'targetRoleSlug': targetRoleSlug,
        'targetRoleLabel': targetRoleLabel,
        'suggestedRoleSlug': suggestedRoleSlug,
        'suggestedRoleLabel': suggestedRoleLabel,
        'resumeUrl': resumeUrl,
        'score': score,
        'matchedSkills': matchedSkills,
        'weakSkills': weakSkills,
        'missingSkills': missingSkills,
        'archivedRoadmaps': archivedRoadmaps,
        'onboardingComplete': onboardingComplete,
        'roadmapVersion': roadmapVersion,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        uid: m['uid'] as String? ?? '',
        // Fix: support both 'name' and legacy 'displayName' field
        name: (m['name'] as String?)?.isNotEmpty == true
            ? m['name'] as String
            : (m['displayName'] as String? ?? ''),
        email: m['email'] as String? ?? '',
        location: m['location'] as String? ?? '',
        education: m['education'] as String? ?? '',
        currentRole: m['currentRole'] as String? ?? '',
        targetRoleSlug: m['targetRoleSlug'] as String?,
        targetRoleLabel: m['targetRoleLabel'] as String?,
        suggestedRoleSlug: m['suggestedRoleSlug'] as String?,
        suggestedRoleLabel: m['suggestedRoleLabel'] as String?,
        resumeUrl: m['resumeUrl'] as String?,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
        score: (m['score'] as num?)?.toInt() ?? 0,
        matchedSkills: List<String>.from(m['matchedSkills'] as List? ?? []),
        weakSkills: List<String>.from(m['weakSkills'] as List? ?? []),
        missingSkills: List<String>.from(m['missingSkills'] as List? ?? []),
        archivedRoadmaps: (m['archivedRoadmaps'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        onboardingComplete: m['onboardingComplete'] as bool? ?? false,
        roadmapVersion: (m['roadmapVersion'] as num?)?.toInt() ?? 1,
      );

  String get initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  UserProfile copyWith({
    String? name,
    String? location,
    String? education,
    String? currentRole,
    bool? onboardingComplete,
  }) =>
      UserProfile(
        uid: uid,
        name: name ?? this.name,
        email: email,
        location: location ?? this.location,
        education: education ?? this.education,
        currentRole: currentRole ?? this.currentRole,
        targetRoleSlug: targetRoleSlug,
        targetRoleLabel: targetRoleLabel,
        suggestedRoleSlug: suggestedRoleSlug,
        suggestedRoleLabel: suggestedRoleLabel,
        resumeUrl: resumeUrl,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        score: score,
        matchedSkills: matchedSkills,
        weakSkills: weakSkills,
        missingSkills: missingSkills,
        archivedRoadmaps: archivedRoadmaps,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        roadmapVersion: roadmapVersion,
      );
}
