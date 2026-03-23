import 'package:cloud_firestore/cloud_firestore.dart';

class SkillModel {
  final String id;
  final String name;
  int level;
  final String category;
  final String source; // 'resume' | 'manual' | 'module'
  final DateTime addedAt;

  SkillModel({
    required this.id,
    required this.name,
    required this.level,
    this.category = 'Other',
    this.source = 'manual',
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Beginner / Intermediate / Advanced label based on level
  String get label =>
      level >= 80 ? 'Advanced' : level >= 55 ? 'Intermediate' : 'Beginner';

  Map<String, dynamic> toMap() => {
        'name': name,
        'level': level.clamp(1, 100),
        'category': category,
        'source': source,
        'addedAt': Timestamp.fromDate(addedAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  factory SkillModel.fromMap(String id, Map<String, dynamic> m) => SkillModel(
        id: id,
        // Null-safe: never crash on missing/wrong-type Firestore data
        name: m['name'] as String? ?? '',
        level: ((m['level'] as num?)?.toInt() ?? 65).clamp(1, 100),
        category: m['category'] as String? ?? 'Other',
        source: m['source'] as String? ?? 'manual',
        addedAt: (m['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  SkillModel copyWith({int? level, String? category}) => SkillModel(
        id: id,
        name: name,
        level: level ?? this.level,
        category: category ?? this.category,
        source: source,
        addedAt: addedAt,
      );
}
