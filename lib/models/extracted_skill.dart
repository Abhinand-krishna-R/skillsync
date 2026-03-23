class ExtractedSkill {
  final String name;
  final int level;
  final String category;
  final double confidence;

  ExtractedSkill({
    required this.name,
    this.level = 65,
    this.category = 'Other',
    this.confidence = 0.7,
  });

  factory ExtractedSkill.fromJson(Map<String, dynamic> json) {
    // Robust parsing to handle potential type mismatches from AI
    final rawLevel = json['level'];
    final parsedLevel = rawLevel is num ? rawLevel.toInt() : (int.tryParse(rawLevel.toString()) ?? 65);
    
    final rawConf = json['confidence'];
    final parsedConf = rawConf is num ? rawConf.toDouble() : (double.tryParse(rawConf.toString()) ?? 0.7);

    return ExtractedSkill(
      name: json['name']?.toString() ?? '',
      level: parsedLevel.clamp(1, 100),
      category: json['category']?.toString() ?? 'Other',
      confidence: parsedConf.clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'level': level,
    'category': category,
    'confidence': confidence,
  };
}
