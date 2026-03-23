
/// Status constants — use these everywhere instead of raw strings.
class ModuleStatus {
  static const locked = 'locked';
  static const active = 'active';
  static const completed = 'completed';
}

class ModuleModel {
  final String id;
  final String title;
  final String description;
  final int hours;
  final List<String> tags;
  String status;
  int progress;
  final Map<String, int> skillBoost;
  final int order;
  final List<Map<String, String>> resources;
  final List<String> practice;
  final List<bool> tasks; // New: persistent checkbox states
  final int roadmapVersion;

  ModuleModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.hours,
    required this.tags,
    required this.order,
    this.status = ModuleStatus.locked,
    this.progress = 0,
    this.skillBoost = const {},
    this.resources = const [],
    this.practice = const [],
    this.tasks = const [],
    this.roadmapVersion = 1,
  });

  bool get isCompleted => status == ModuleStatus.completed;
  bool get isActive => status == ModuleStatus.active;
  bool get isLocked => status == ModuleStatus.locked;

  ModuleModel copyWith({String? status, int? progress, List<bool>? tasks}) => ModuleModel(
    id: id,
    title: title,
    description: description,
    hours: hours,
    tags: tags,
    order: order,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    skillBoost: skillBoost,
    resources: resources,
    practice: practice,
    tasks: tasks ?? this.tasks,
    roadmapVersion: roadmapVersion,
  );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'hours': hours,
        'tags': tags,
        'status': status,
        'progress': progress,
        'skillBoost': skillBoost,
        'order': order,
        'resources': resources,
        'practice': practice,
        'tasks': tasks,
        'roadmapVersion': roadmapVersion,
      };

  factory ModuleModel.fromMap(String id, Map<String, dynamic> m) {
    // Normalize legacy 'done' status to 'completed'
    String status = m['status'] as String? ?? ModuleStatus.locked;
    if (status == 'done') status = ModuleStatus.completed;

    return ModuleModel(
      id: id,
      title: m['title'] as String? ?? 'Module',
      description: m['description'] as String? ?? '',
      hours: (m['hours'] as num?)?.toInt() ?? 0,
      tags: List<String>.from(m['tags'] as List? ?? []),
      status: status,
      progress: (m['progress'] as num?)?.toInt() ?? 0,
      skillBoost: Map<String, int>.from(
          (m['skillBoost'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, (v as num).toInt())) ??
              {}),
      order: (m['order'] as num?)?.toInt() ?? 1,
      resources: (m['resources'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
      practice: List<String>.from(m['practice'] as List? ?? []),
      tasks: List<bool>.from(m['tasks'] as List? ?? []),
      roadmapVersion: (m['roadmapVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
