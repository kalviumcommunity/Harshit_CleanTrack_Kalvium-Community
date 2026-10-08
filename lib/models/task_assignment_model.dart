import 'package:cloud_firestore/cloud_firestore.dart';

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

DateTime _parseDateTime(dynamic value, [DateTime? fallback]) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return fallback ?? DateTime.now();
}

class TaskAssignmentModel {
  final String assignmentId;
  final DocumentReference? taskRef;
  final String taskId;
  final DocumentReference? workerRef;
  final String workerId;
  final DocumentReference? supervisorRef;
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
    required this.assignmentId,
    this.taskRef,
    required this.taskId,
    this.workerRef,
    required this.workerId,
    this.supervisorRef,
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

  Map<String, dynamic> toJson() {
    return {
      'assignmentId': assignmentId,
      'taskRef': taskRef,
      'taskId': taskId,
      'workerRef': workerRef,
      'workerId': workerId,
      'supervisorRef': supervisorRef,
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
      assignmentId: id,
      taskRef: map['taskRef'] is DocumentReference ? map['taskRef'] as DocumentReference : null,
      taskId: map['taskId'] ?? '',
      workerRef: map['workerRef'] is DocumentReference ? map['workerRef'] as DocumentReference : null,
      workerId: map['workerId'] ?? '',
      supervisorRef: map['supervisorRef'] is DocumentReference ? map['supervisorRef'] as DocumentReference : null,
      wardId: map['wardId'] ?? '',
      assignmentNumber: (map['assignmentNumber'] as num?)?.toInt() ?? 1,
      supervisorFeedback: map['supervisorFeedback'],
      attempts: (map['attempts'] as num?)?.toInt() ?? 1,
      deadline: _parseDateTime(map['deadline'], DateTime.now().add(const Duration(hours: 24))),
      assignedAt: _parseDateTime(map['assignedAt']),
      completedAt: map['completedAt'] != null ? _parseDateTime(map['completedAt']) : null,
      verifiedAt: map['verifiedAt'] != null ? _parseDateTime(map['verifiedAt']) : null,
      status: AssignmentStatus.fromString(map['status']),
    );
  }

  TaskAssignmentModel copyWith({
    String? assignmentId,
    DocumentReference? taskRef,
    String? taskId,
    DocumentReference? workerRef,
    String? workerId,
    DocumentReference? supervisorRef,
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
      assignmentId: assignmentId ?? this.assignmentId,
      taskRef: taskRef ?? this.taskRef,
      taskId: taskId ?? this.taskId,
      workerRef: workerRef ?? this.workerRef,
      workerId: workerId ?? this.workerId,
      supervisorRef: supervisorRef ?? this.supervisorRef,
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
