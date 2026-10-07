import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus {
  open,
  closed;

  String get displayName {
    switch (this) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.closed:
        return 'Closed';
    }
  }

  static TaskStatus fromString(String? status) {
    if (status == null) return TaskStatus.open;
    switch (status.toLowerCase()) {
      case 'closed':
        return TaskStatus.closed;
      case 'open':
      default:
        return TaskStatus.open;
    }
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

class TaskModel {
  final String taskId;
  final DocumentReference? wardRef;
  final String wardId;
  final DocumentReference? createdByRef;
  final String title;
  final String description;
  final DateTime createdAt;
  final TaskStatus status;
  final String? currentAssignmentId;

  TaskModel({
    required this.taskId,
    this.wardRef,
    required this.wardId,
    this.createdByRef,
    required this.title,
    required this.description,
    DateTime? createdAt,
    this.status = TaskStatus.open,
    this.currentAssignmentId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'wardRef': wardRef,
      'wardId': wardId,
      'createdByRef': createdByRef,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'status': status.displayName,
      'currentAssignmentId': currentAssignmentId,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      taskId: id,
      wardRef: map['wardRef'] is DocumentReference ? map['wardRef'] as DocumentReference : null,
      wardId: map['wardId'] ?? '',
      createdByRef: map['createdByRef'] is DocumentReference ? map['createdByRef'] as DocumentReference : null,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      status: TaskStatus.fromString(map['status']),
      currentAssignmentId: map['currentAssignmentId'],
    );
  }

  TaskModel copyWith({
    String? taskId,
    DocumentReference? wardRef,
    String? wardId,
    DocumentReference? createdByRef,
    String? title,
    String? description,
    DateTime? createdAt,
    TaskStatus? status,
    String? currentAssignmentId,
  }) {
    return TaskModel(
      taskId: taskId ?? this.taskId,
      wardRef: wardRef ?? this.wardRef,
      wardId: wardId ?? this.wardId,
      createdByRef: createdByRef ?? this.createdByRef,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      currentAssignmentId: currentAssignmentId ?? this.currentAssignmentId,
    );
  }
}
