import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message; // stored as 'body' in Firestore
  bool read;
  final String icon;
  final int colorValue;
  final DateTime createdAt;

  IconData get iconData => switch (icon) {
    'sparkles'  => Icons.auto_awesome_rounded,
    'award'     => Icons.emoji_events_outlined,
    'file_text' => Icons.description_outlined,
    'target'    => Icons.track_changes_rounded,
    _           => Icons.notifications_outlined,
  };

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.icon = 'sparkles',
    this.colorValue = 0xFFA855F7, // Default purple
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': message,
        'icon': icon,
        'colorValue': colorValue,
        'read': read,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory NotificationModel.fromMap(String id, Map<String, dynamic> m) =>
      NotificationModel(
        id: id,
        title: m['title'] as String? ?? '',
        // Support both 'body' (new) and 'message' (legacy)
        message: m['body'] as String? ?? m['message'] as String? ?? '',
        icon: m['icon'] as String? ?? 'sparkles',
        colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFFA855F7,
        read: m['read'] as bool? ?? false,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
