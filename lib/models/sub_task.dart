import 'package:flutter/foundation.dart';

/// A small checkable item nested inside a [Task]. Subtasks are persisted as
/// part of the parent task; they are not addressable on their own.
@immutable
class SubTask {
  const SubTask({
    required this.id,
    required this.title,
    this.completed = false,
  });

  final String id;
  final String title;
  final bool completed;

  SubTask copyWith({String? id, String? title, bool? completed}) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
      };

  factory SubTask.fromJson(Map<String, dynamic> json) => SubTask(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is SubTask &&
      other.id == id &&
      other.title == title &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(id, title, completed);
}
