enum AssignmentStatus {
  completed,
  pendingVerification,
  verified,
  autoVerified,
  notCompleted;

  String get displayName {
    switch (this) {
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.pendingVerification:
        return 'Pending Verification';
      case AssignmentStatus.verified:
        return 'Verified';
      case AssignmentStatus.autoVerified:
        return 'Auto Verified';
      case AssignmentStatus.notCompleted:
        return 'Not Completed';
    }
  }

  static AssignmentStatus fromString(String? status) {
    if (status == null) return AssignmentStatus.pendingVerification;
    switch (status.toLowerCase()) {
      case 'completed':
        return AssignmentStatus.completed;
      case 'pending verification':
      case 'pending_verification':
        return AssignmentStatus.pendingVerification;
      case 'verified':
        return AssignmentStatus.verified;
      case 'auto verified':
      case 'auto_verified':
        return AssignmentStatus.autoVerified;
      case 'not completed':
      case 'not_completed':
        return AssignmentStatus.notCompleted;
      default:
        return AssignmentStatus.pendingVerification;
    }
  }
}

class TaskAssignmentModel {
  final String id;
  final String taskId;
  final String workerId;
  final String? supervisorId;
  final String wardId;
  final int assignmentNumber;
  final String? supervisorFeedback;
  final int attempts;
  final DateTime deadline;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final DateTime? verifiedAt;
  final AssignmentStatus status;

  TaskAssignmentModel({
    required this.id,
    required this.taskId,
    required this.workerId,
    this.supervisorId,
    required this.wardId,
    this.assignmentNumber = 1,
    this.supervisorFeedback,
    this.attempts = 1,
    required this.deadline,
    DateTime? assignedAt,
    this.completedAt,
    this.verifiedAt,
    this.status = AssignmentStatus.pendingVerification,
  }) : assignedAt = assignedAt ?? DateTime.now();

  String get assignmentId => id;

  Map<String, dynamic> toJson() {
    return {
      'assignmentId': id,
      'id': id,
      'taskId': taskId,
      'workerId': workerId,
      'supervisorId': supervisorId,
      'wardId': wardId,
      'assignmentNumber': assignmentNumber,
      'supervisorFeedback': supervisorFeedback,
      'attempts': attempts,
      'deadline': deadline.toIso8601String(),
      'assignedAt': assignedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'verifiedAt': verifiedAt?.toIso8601String(),
      'status': status.displayName,
    };
  }

  factory TaskAssignmentModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskAssignmentModel(
      id: id,
      taskId: map['taskId'] ?? '',
      workerId: map['workerId'] ?? '',
      supervisorId: map['supervisorId'],
      wardId: map['wardId'] ?? '',
      assignmentNumber: (map['assignmentNumber'] as num?)?.toInt() ?? 1,
      supervisorFeedback: map['supervisorFeedback'],
      attempts: (map['attempts'] as num?)?.toInt() ?? 1,
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'].toString()) ?? DateTime.now().add(const Duration(hours: 24))
          : DateTime.now().add(const Duration(hours: 24)),
      assignedAt: map['assignedAt'] != null
          ? DateTime.tryParse(map['assignedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      verifiedAt: map['verifiedAt'] != null
          ? DateTime.tryParse(map['verifiedAt'].toString())
          : null,
      status: AssignmentStatus.fromString(map['status']),
    );
  }

  TaskAssignmentModel copyWith({
    String? id,
    String? taskId,
    String? workerId,
    String? supervisorId,
    String? wardId,
    int? assignmentNumber,
    String? supervisorFeedback,
    int? attempts,
    DateTime? deadline,
    DateTime? assignedAt,
    DateTime? completedAt,
    DateTime? verifiedAt,
    AssignmentStatus? status,
  }) {
    return TaskAssignmentModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      workerId: workerId ?? this.workerId,
      supervisorId: supervisorId ?? this.supervisorId,
      wardId: wardId ?? this.wardId,
      assignmentNumber: assignmentNumber ?? this.assignmentNumber,
      supervisorFeedback: supervisorFeedback ?? this.supervisorFeedback,
      attempts: attempts ?? this.attempts,
      deadline: deadline ?? this.deadline,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      status: status ?? this.status,
    );
  }
}
