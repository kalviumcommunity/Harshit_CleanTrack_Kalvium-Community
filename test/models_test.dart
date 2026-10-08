import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/models/ward_model.dart';
import 'package:cleantrack/models/task_model.dart';
import 'package:cleantrack/models/task_assignment_model.dart';

void main() {
  group('13.1 UserModel Tests', () {
    test('UserRole and UserStatus string conversions', () {
      expect(UserRole.admin.displayName, 'Admin');
      expect(UserRole.supervisor.displayName, 'Supervisor');
      expect(UserRole.worker.displayName, 'Worker');
      expect(UserRole.fromString('Admin'), UserRole.admin);
      expect(UserRole.fromString('Supervisor'), UserRole.supervisor);
      expect(UserRole.fromString('Worker'), UserRole.worker);

      expect(UserStatus.pending.displayName, 'Pending');
      expect(UserStatus.available.displayName, 'Available');
      expect(UserStatus.busy.displayName, 'Busy');
      expect(UserStatus.suspended.displayName, 'Suspended');
      expect(UserStatus.assigned.displayName, 'Assigned');
    });

    test('UserModel serialization and exact PRD 13.1 fields', () {
      final user = UserModel(
        userId: 'usr-001',
        name: 'Aarav Patel',
        employeeId: 'WRK-101',
        email: 'aarav@hospital.org',
        role: UserRole.worker,
        status: UserStatus.available,
        wardId: 'ward-01',
        activeAssignmentId: 'assign-55',
      );

      final json = user.toJson();
      expect(json['userId'], 'usr-001');
      expect(json['name'], 'Aarav Patel');
      expect(json['employeeId'], 'WRK-101');
      expect(json['email'], 'aarav@hospital.org');
      expect(json['role'], 'Worker');
      expect(json['status'], 'Available');
      expect(json['wardId'], 'ward-01');
      expect(json['activeAssignmentId'], 'assign-55');

      final fromMap = UserModel.fromMap(json, 'usr-001');
      expect(fromMap.userId, 'usr-001');
      expect(fromMap.name, 'Aarav Patel');
      expect(fromMap.employeeId, 'WRK-101');
      expect(fromMap.email, 'aarav@hospital.org');
      expect(fromMap.role, UserRole.worker);
      expect(fromMap.status, UserStatus.available);
      expect(fromMap.wardId, 'ward-01');
      expect(fromMap.activeAssignmentId, 'assign-55');
    });
  });

  group('13.2 WardModel Tests', () {
    test('WardModel serialization and exact PRD 13.2 fields', () {
      final now = DateTime(2026, 10, 7, 10, 0);
      final ward = WardModel(
        wardId: 'ward-01',
        name: 'ICU Ward',
        supervisorId: 'sup-123',
        createdAt: now,
      );

      final json = ward.toJson();
      expect(json['wardId'], 'ward-01');
      expect(json['name'], 'ICU Ward');
      expect(json['supervisorId'], 'sup-123');

      final fromMap = WardModel.fromMap(json, 'ward-01');
      expect(fromMap.wardId, 'ward-01');
      expect(fromMap.name, 'ICU Ward');
      expect(fromMap.supervisorId, 'sup-123');

      final updated = ward.copyWith(name: 'Emergency Ward');
      expect(updated.wardId, 'ward-01');
      expect(updated.name, 'Emergency Ward');
    });
  });

  group('13.3 TaskModel Tests', () {
    test('TaskStatus parsing and display names', () {
      expect(TaskStatus.open.displayName, 'Open');
      expect(TaskStatus.closed.displayName, 'Closed');
      expect(TaskStatus.fromString('Open'), TaskStatus.open);
      expect(TaskStatus.fromString('closed'), TaskStatus.closed);
    });

    test('TaskModel serialization and exact PRD 13.3 fields', () {
      final task = TaskModel(
        taskId: 'task-100',
        wardId: 'ward-01',
        title: 'Floor sanitization',
        description: 'Sanitize room 101 to 105',
        status: TaskStatus.open,
        currentAssignmentId: 'assign-01',
      );

      final json = task.toJson();
      expect(json['taskId'], 'task-100');
      expect(json['wardId'], 'ward-01');
      expect(json['title'], 'Floor sanitization');
      expect(json['description'], 'Sanitize room 101 to 105');
      expect(json['status'], 'Open');
      expect(json['currentAssignmentId'], 'assign-01');

      final fromMap = TaskModel.fromMap(json, 'task-100');
      expect(fromMap.taskId, 'task-100');
      expect(fromMap.wardId, 'ward-01');
      expect(fromMap.title, 'Floor sanitization');
      expect(fromMap.description, 'Sanitize room 101 to 105');
      expect(fromMap.status, TaskStatus.open);
      expect(fromMap.currentAssignmentId, 'assign-01');

      final closedTask = task.copyWith(status: TaskStatus.closed);
      expect(closedTask.status, TaskStatus.closed);
    });
  });

  group('13.4 TaskAssignmentModel Tests', () {
    test('AssignmentStatus display names and parsing', () {
      expect(AssignmentStatus.completed.displayName, 'Completed');
      expect(AssignmentStatus.pendingVerification.displayName, 'Pending Verification');
      expect(AssignmentStatus.verified.displayName, 'Verified');
      expect(AssignmentStatus.autoVerified.displayName, 'Auto Verified');
      expect(AssignmentStatus.notCompleted.displayName, 'Not Completed');

      expect(AssignmentStatus.fromString('Completed'), AssignmentStatus.completed);
      expect(AssignmentStatus.fromString('Pending Verification'), AssignmentStatus.pendingVerification);
      expect(AssignmentStatus.fromString('Verified'), AssignmentStatus.verified);
      expect(AssignmentStatus.fromString('Auto Verified'), AssignmentStatus.autoVerified);
      expect(AssignmentStatus.fromString('Not Completed'), AssignmentStatus.notCompleted);
    });

    test('TaskAssignmentModel serialization and exact PRD 13.4 fields', () {
      final deadline = DateTime(2026, 10, 7, 18, 0);
      final assignment = TaskAssignmentModel(
        assignmentId: 'assign-01',
        taskId: 'task-100',
        workerId: 'wrk-001',
        wardId: 'ward-01',
        assignmentNumber: 1,
        attempts: 1,
        supervisorFeedback: 'Please clean corners properly',
        deadline: deadline,
        status: AssignmentStatus.pendingVerification,
      );

      final json = assignment.toJson();
      expect(json['assignmentId'], 'assign-01');
      expect(json['taskId'], 'task-100');
      expect(json['workerId'], 'wrk-001');
      expect(json['wardId'], 'ward-01');
      expect(json['assignmentNumber'], 1);
      expect(json['attempts'], 1);
      expect(json['supervisorFeedback'], 'Please clean corners properly');
      expect(json['status'], 'Pending Verification');

      final fromMap = TaskAssignmentModel.fromMap(json, 'assign-01');
      expect(fromMap.assignmentId, 'assign-01');
      expect(fromMap.taskId, 'task-100');
      expect(fromMap.workerId, 'wrk-001');
      expect(fromMap.wardId, 'ward-01');
      expect(fromMap.assignmentNumber, 1);
      expect(fromMap.attempts, 1);
      expect(fromMap.supervisorFeedback, 'Please clean corners properly');
      expect(fromMap.status, AssignmentStatus.pendingVerification);

      final verified = assignment.copyWith(
        status: AssignmentStatus.verified,
        verifiedAt: DateTime.now(),
      );
      expect(verified.status, AssignmentStatus.verified);
      expect(verified.verifiedAt, isNotNull);
    });
  });
}
