import 'package:flutter/material.dart';
import 'roles/business_roles.dart';
import 'roles/design_roles.dart';
import 'roles/education_roles.dart';
import 'roles/engineering_roles.dart';
import 'roles/finance_roles.dart';
import 'roles/healthcare_roles.dart';
import 'roles/marketing_roles.dart';
import 'roles/tech_roles.dart';


/// Static roles reference — lives in code, not Firestore.
class CareerRole {
  final String slug, name, icon, category, demand, salary, description, source, careerCluster;
  final List<String> requiredSkills, tools, aiTips;
  final Map<String, double> weights;
  final Map<String, int> requiredLevels;
  final Color color;
  final bool qualificationRequired;
  final List<String> qualifications;
  final String qualificationNote;
  final DateTime? createdAt;
  final double difficulty;

  const CareerRole({
    required this.slug,
    required this.name,
    required this.icon,
    required this.category,
    required this.demand,
    required this.salary,
    required this.description,
    required this.requiredSkills,
    required this.weights,
    required this.requiredLevels,
    required this.tools,
    required this.aiTips,
    required this.color,
    required this.qualificationRequired,
    required this.qualifications,
    required this.qualificationNote,
    this.source = 'local',
    this.careerCluster = 'General',
    this.createdAt,
    this.difficulty = 1.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'name': name,
      'icon': icon,
      'category': category,
      'demand': demand,
      'salary': salary,
      'description': description,
      'requiredSkills': requiredSkills,
      'weights': weights,
      'requiredLevels': requiredLevels,
      'tools': tools,
      'aiTips': aiTips,
      'color': color.value,
      'qualificationRequired': qualificationRequired,
      'qualifications': qualifications,
      'qualificationNote': qualificationNote,
      'source': source,
      'careerCluster': careerCluster,
      'createdAt': createdAt?.toIso8601String(),
      'difficulty': difficulty,
    };
  }

  factory CareerRole.fromMap(Map<String, dynamic> map) {
    return CareerRole(
      slug: map['slug'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? 'work',
      category: map['category'] ?? 'General',
      demand: map['demand'] ?? 'Moderate',
      salary: map['salary'] ?? 'N/A',
      description: map['description'] ?? '',
      requiredSkills: List<String>.from(map['requiredSkills'] ?? []),
      weights: Map<String, double>.from(map['weights'] ?? {}),
      requiredLevels: Map<String, int>.from(map['requiredLevels'] ?? {}),
      tools: List<String>.from(map['tools'] ?? []),
      aiTips: List<String>.from(map['aiTips'] ?? []),
      color: Color(map['color'] as int? ?? Colors.blue.value),
      qualificationRequired: map['qualificationRequired'] ?? false,
      qualifications: List<String>.from(map['qualifications'] ?? []),
      qualificationNote: map['qualificationNote'] ?? '',
      source: map['source'] ?? 'ai',
      careerCluster: map['careerCluster'] ?? 'General',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) : null,
      difficulty: (map['difficulty'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class RolesDB {
  // ─── Predefined Roles ──────────────────────────────────────────
  static const Map<String, CareerRole> roles = {
    ...techRoles,
    ...designRoles,
    ...businessRoles,
    ...marketingRoles,
    ...financeRoles,
    ...engineeringRoles,
    ...healthcareRoles,
    ...educationRoles,
  };
  // ─── Skill Normalization Map ───────────────────────────────────
  // Maps common variants/abbreviations to canonical skill names
  static const Map<String, String> _skillDictionary = {
    // Tech & programming variants
    'js': 'JavaScript',
    'javascript': 'JavaScript',
    'ts': 'TypeScript',
    'typescript': 'TypeScript',
    'nodejs': 'Node.js',
    'node.js': 'Node.js',
    'node': 'Node.js',
    'py': 'Python',
    'python3': 'Python',
    'ml': 'Machine Learning',
    'ai': 'Artificial Intelligence',
    'dl': 'Deep Learning',
    'react.js': 'React',
    'reactjs': 'React',
    'react native': 'React Native',
    'vue.js': 'Vue',
    'vuejs': 'Vue',
    'postgresql': 'PostgreSQL',
    'postgres': 'PostgreSQL',
    'mongodb': 'MongoDB',
    'mongo': 'MongoDB',
    'css3': 'CSS',
    'html5': 'HTML',
    'html': 'HTML',
    'aws': 'AWS',
    'amazon web services': 'AWS',
    'gcp': 'Google Cloud',
    'google cloud platform': 'Google Cloud',
    'ci/cd': 'CI/CD',
    'cicd': 'CI/CD',
    'rest api': 'REST APIs',
    'rest apis': 'REST APIs',
    'api design': 'API Design',
    'state mgmt': 'State Management',
    'ux': 'UX Design',
    'ui/ux': 'UI/UX',
    'figma design': 'Figma',
    'adobe xd': 'Adobe XD',
    'xd': 'Adobe XD',
    'ms excel': 'Excel',
    'microsoft excel': 'Excel',
    'excel': 'Excel',
    'sk-learn': 'Scikit-learn',
    'sklearn': 'Scikit-learn',
    'tensorflow': 'TensorFlow',
    'tf': 'TensorFlow',
    'pytorch': 'PyTorch',
    'git/github': 'Git',
    'github': 'Git',
    'git': 'Git',
    'dotnet': '.NET',
    'c sharp': 'C#',
    'c#': 'C#',
    'cpp': 'C++',
    'c++': 'C++',
    // Expanded Skills
    'search engine optimization': 'SEO',
    'seo': 'SEO',
    'search engine marketing': 'SEM',
    'sem': 'SEM',
    'digital marketing': 'Marketing',
    'social media': 'Social Media Marketing',
    'smm': 'Social Media Marketing',
    'google analytics': 'Google Analytics',
    'ga': 'Google Analytics',
    'ga4': 'Google Analytics',
    'adobe illustrator': 'Adobe Illustrator',
    'illustrator': 'Adobe Illustrator',
    'photoshop': 'Adobe Photoshop',
    'adobe photoshop': 'Adobe Photoshop',
    'after effects': 'After Effects',
    'premiere': 'Premiere Pro',
    'premiere pro': 'Premiere Pro',
    'financial modelling': 'Financial Modeling',
    'financial modeling': 'Financial Modeling',
    'mergers and acquisitions': 'M&A',
    'm&a': 'M&A',
    'ca': 'Chartered Accountancy',
    'cpa': 'CPA',
    'cad': 'AutoCAD',
    'autocad': 'AutoCAD',
    'solid works': 'SolidWorks',
    'solidworks': 'SolidWorks',
    'matlab': 'MATLAB',
    'emr': 'EMR Proficiency',
    'electronic medical records': 'EMR Proficiency',
    'cpr': 'CPR/BLS',
    'bls': 'CPR/BLS',
    'pedagogy': 'Pedagogy',
    'lesson planning': 'Lesson Planning',
    'teaching': 'Teaching',
    'express.js': 'Express',
    'expressjs': 'Express',
    'express': 'Express',
    'next.js': 'Next.js',
    'nextjs': 'Next.js',
    'tailwind': 'Tailwind CSS',
    'tailwindcss': 'Tailwind CSS',
    'flutter framework': 'Flutter',
    'flutter': 'Flutter',
    'dart lang': 'Dart',
    'dart': 'Dart',
    'sql': 'SQL',
    'mysql': 'MySQL',
    'sqlite': 'SQLite',
    'restful api': 'REST',
    'rest': 'REST',
  };

  /// Normalize a skill name to its canonical form.
  static String normalizeSkill(String raw) {
    final lower = raw.trim().toLowerCase();
    return _skillDictionary[lower] ?? _toTitleCase(raw.trim());
  }

  static String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      // Preserve all-caps abbreviations (AWS, SQL, CSS, etc.)
      if (w.length <= 4 && w == w.toUpperCase()) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Specialized normalization for skill matching to handle common aliases.
  static String normalizeForMatch(String skill) {
    final s = skill.trim().toLowerCase();
    final canonical = _skillDictionary[s] ?? s;
    return canonical.toLowerCase();
  }

  /// Returns true if two skill names match (canonical or fuzzy).
  static bool isMatch(String userSkill, String roleReq) {
    final u = normalizeForMatch(userSkill);
    final r = normalizeForMatch(roleReq);
    if (u == r) return true;

    // Space-insensitive fallback (e.g. "React JS" vs "ReactJS")
    if (u.replaceAll(' ', '') == r.replaceAll(' ', '')) return true;

    // Fuzzy fallback: contains matching for significant terms
    if (u.length >= 4 && r.length >= 4) {
      if (u.contains(r) || r.contains(u)) return true;
    }

    return false;
  }

  /// Returns canonical name (e.g. "React" instead of "reactjs")
  static String canonicalName(String skill) {
    final s = skill.trim().toLowerCase();
    return _skillDictionary[s] ?? skill;
  }

  // ─── Safe Role Lookup ──────────────────────────────────────────
  static CareerRole? safeGet(String slug) => roles[slug];

  // ─── Slug from name ────────────────────────────────────────────
  static String slugify(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}
