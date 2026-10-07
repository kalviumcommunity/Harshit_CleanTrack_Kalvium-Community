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

class TaskModel {
  final String id;
  final String wardId;
  final String createdBy;
  final String title;
  final String description;
  final TaskStatus status;
  final String? currentAssignmentId;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.wardId,
    required this.createdBy,
    required this.title,
    required this.description,
    this.status = TaskStatus.open,
    this.currentAssignmentId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get taskId => id;

  Map<String, dynamic> toJson() {
    return {
      'taskId': id,
      'id': id,
      'wardId': wardId,
      'createdBy': createdBy,
      'title': title,
      'description': description,
      'status': status.displayName,
      'currentAssignmentId': currentAssignmentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      wardId: map['wardId'] ?? '',
      createdBy: map['createdBy'] ?? map['supervisorId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: TaskStatus.fromString(map['status']),
      currentAssignmentId: map['currentAssignmentId'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  TaskModel copyWith({
    String? id,
    String? wardId,
    String? createdBy,
    String? title,
    String? description,
    TaskStatus? status,
    String? currentAssignmentId,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      wardId: wardId ?? this.wardId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      currentAssignmentId: currentAssignmentId ?? this.currentAssignmentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
