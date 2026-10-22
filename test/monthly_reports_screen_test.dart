import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/models/task_assignment_model.dart';
import 'package:cleantrack/models/task_model.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/screens/monthly_reports_screen.dart';
import 'package:cleantrack/services/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('counts each task once using its current assignment', (
    tester,
  ) async {
    final service = FirestoreService();
    service.clearAllData();
    final month = DateTime.now();

    service.seedTask(
      TaskModel(
        taskId: 'task-1',
        wardId: 'ward_icu_1',
        title: 'Deep clean',
        description: 'Deep clean the ward',
        createdAt: month,
        currentAssignmentId: 'replacement-assignment',
      ),
    );
    service.seedAssignment(
      TaskAssignmentModel(
        assignmentId: 'failed-assignment',
        taskId: 'task-1',
        workerId: 'suspended-worker',
        wardId: 'ward_icu_1',
        deadline: month.add(const Duration(days: 1)),
        assignedAt: month,
        assignmentNumber: 1,
        status: AssignmentStatus.notCompleted,
      ),
    );
    service.seedAssignment(
      TaskAssignmentModel(
        assignmentId: 'replacement-assignment',
        taskId: 'task-1',
        workerId: 'active-worker',
        wardId: 'ward_icu_1',
        deadline: month.add(const Duration(days: 1)),
        assignedAt: month,
        assignmentNumber: 2,
        status: AssignmentStatus.verified,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyReportsScreen(
          firestoreService: service,
          adminUser: UserModel(
            userId: 'admin',
            name: 'Rajesh Kumar',
            employeeId: 'ADM-001',
            email: 'admin@example.com',
            role: UserRole.admin,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly Ward Reports'), findsOneWidget);
    expect(find.text('RK'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);
    expect(find.text('VERIFIED'), findsWidgets);
    expect(find.text('NOT COMPLETED'), findsWidgets);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('shows a zero-data report without seeded assignment values', (
    tester,
  ) async {
    final service = FirestoreService();
    service.clearAllData();

    await tester.pumpWidget(
      MaterialApp(home: MonthlyReportsScreen(firestoreService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsWidgets);
    expect(find.text('No ward activity for this month.'), findsNothing);
  });
}
