import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/models/ward_model.dart';
import 'package:cleantrack/models/task_model.dart';
import 'package:cleantrack/models/task_assignment_model.dart';

void main() {
  group('WardModel Tests', () {
    test('WardModel serialization, fromMap, and copyWith', () {
      final now = DateTime(2026, 10, 7, 10, 0);
      final ward = WardModel(
        id: 'ward-01',
        name: 'ICU Ward',
        supervisorId: 'sup-123',
        createdAt: now,
      );

      expect(ward.wardId, 'ward-01');
      expect(ward.name, 'ICU Ward');
      expect(ward.supervisorId, 'sup-123');

      final json = ward.toJson();
      expect(json['wardId'], 'ward-01');
      expect(json['name'], 'ICU Ward');
      expect(json['supervisorId'], 'sup-123');

      final fromMap = WardModel.fromMap(json, 'ward-01');
      expect(fromMap.id, 'ward-01');
      expect(fromMap.name, 'ICU Ward');
      expect(fromMap.supervisorId, 'sup-123');

      final updated = ward.copyWith(name: 'Emergency Ward');
      expect(updated.name, 'Emergency Ward');
      expect(updated.id, 'ward-01');
    });
  });

  group('TaskModel Tests', () {
    test('TaskStatus parsing and display names', () {
      expect(TaskStatus.open.displayName, 'Open');
      expect(TaskStatus.closed.displayName, 'Closed');
      expect(TaskStatus.fromString('Open'), TaskStatus.open);
      expect(TaskStatus.fromString('closed'), TaskStatus.closed);
      expect(TaskStatus.fromString(null), TaskStatus.open);
    });

    test('TaskModel serialization, fromMap, and copyWith', () {
      final task = TaskModel(
        id: 'task-100',
        wardId: 'ward-01',
        createdBy: 'sup-123',
        title: 'Floor sanitization',
        description: 'Sanitize room 101 to 105',
        status: TaskStatus.open,
        currentAssignmentId: 'assign-01',
      );

      expect(task.taskId, 'task-100');
      expect(task.title, 'Floor sanitization');
      expect(task.status, TaskStatus.open);

      final json = task.toJson();
      expect(json['taskId'], 'task-100');
      expect(json['status'], 'Open');
      expect(json['wardId'], 'ward-01');

      final fromMap = TaskModel.fromMap(json, 'task-100');
      expect(fromMap.id, 'task-100');
      expect(fromMap.title, 'Floor sanitization');
      expect(fromMap.status, TaskStatus.open);
      expect(fromMap.currentAssignmentId, 'assign-01');

      final closedTask = task.copyWith(status: TaskStatus.closed);
      expect(closedTask.status, TaskStatus.closed);
    });
  });

  group('TaskAssignmentModel Tests', () {
    test('AssignmentStatus parsing and display names', () {
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

    test('TaskAssignmentModel serialization, fromMap, and copyWith', () {
      final deadline = DateTime(2026, 10, 7, 18, 0);
      final assignment = TaskAssignmentModel(
        id: 'assign-01',
        taskId: 'task-100',
        workerId: 'wrk-001',
        supervisorId: 'sup-001',
        wardId: 'ward-01',
        assignmentNumber: 1,
        attempts: 1,
        supervisorFeedback: 'Please clean corners properly',
        deadline: deadline,
        status: AssignmentStatus.pendingVerification,
      );

      expect(assignment.assignmentId, 'assign-01');
      expect(assignment.supervisorFeedback, 'Please clean corners properly');

      final json = assignment.toJson();
      expect(json['assignmentId'], 'assign-01');
      expect(json['status'], 'Pending Verification');
      expect(json['attempts'], 1);

      final fromMap = TaskAssignmentModel.fromMap(json, 'assign-01');
      expect(fromMap.id, 'assign-01');
      expect(fromMap.taskId, 'task-100');
      expect(fromMap.workerId, 'wrk-001');
      expect(fromMap.status, AssignmentStatus.pendingVerification);
      expect(fromMap.supervisorFeedback, 'Please clean corners properly');

      final verified = assignment.copyWith(
        status: AssignmentStatus.verified,
        verifiedAt: DateTime.now(),
      );
      expect(verified.status, AssignmentStatus.verified);
      expect(verified.verifiedAt, isNotNull);
    });
  });
}
