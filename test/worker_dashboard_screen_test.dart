import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/models/task_model.dart';
import 'package:cleantrack/models/task_assignment_model.dart';
import 'package:cleantrack/services/firestore_service.dart';
import 'package:cleantrack/screens/worker_dashboard_screen.dart';

void main() {
  group('WorkerDashboardScreen Tests', () {
    Widget buildDashboard({UserModel? user, FirestoreService? firestoreService}) {
      return MaterialApp(
        home: WorkerDashboardScreen(
          user: user,
          firestoreService: firestoreService,
        ),
      );
    }

    testWidgets('Renders active task view matching design specifications',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestoreService = FirestoreService();
      firestoreService.seedTask(TaskModel(
        taskId: 'task-1',
        wardId: 'ICU',
        title: 'ICU Floor Cleaning',
        description: 'Sanitize and disinfect ICU patient bays',
        createdAt: DateTime.now(),
      ));
      firestoreService.seedAssignment(TaskAssignmentModel(
        assignmentId: 'assign-1',
        taskId: 'task-1',
        workerId: 'wrk-125',
        wardId: 'ICU',
        assignmentNumber: 1,
        attempts: 1,
        deadline: DateTime(2026, 10, 12, 10, 30),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.completed,
      ));

      final worker = UserModel(
        userId: 'wrk-125',
        name: 'Ravi Kumar',
        employeeId: 'WRK-125',
        email: 'ravi@hospital.org',
        role: UserRole.worker,
        wardId: 'ICU',
        status: UserStatus.busy,
        activeAssignmentId: 'assign-1',
      );

      await tester.pumpWidget(buildDashboard(user: worker, firestoreService: firestoreService));
      await tester.pumpAndSettle();

      // App bar & top branding
      expect(find.text('CleanTrack'), findsOneWidget);
      expect(find.text('HOSPITAL HOUSEKEEPING MANAGEMENT'), findsOneWidget);
      expect(find.text('Worker Dashboard'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('ID: WRK-125'), findsOneWidget);
      expect(find.text('ICU Ward'), findsOneWidget);
      expect(find.byKey(const Key('workerLogoutButton')), findsOneWidget);

      // Task Card details matching screenshot (Ward box removed as it is shown in profile card)
      expect(find.text('WARD: ICU'), findsNothing);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('ICU Floor Cleaning'), findsOneWidget);
      expect(find.text('TARGET DEADLINE'), findsOneWidget);
      expect(find.text('10:30 AM'), findsOneWidget);
      expect(find.text('Failed Attempts: 1 / 3'), findsOneWidget);
      expect(
        find.text('Reaching 3 failed attempts results in suspension for this task.'),
        findsOneWidget,
      );

      // Verify worker popup menu displays email
      await tester.tap(find.byKey(const Key('workerLogoutButton')));
      await tester.pumpAndSettle();
      expect(find.text('ravi@hospital.org'), findsOneWidget);
      expect(find.text('LOG OUT'), findsOneWidget);
    });

    testWidgets('Renders No Task Available view when worker has no active task',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final availableWorker = UserModel(
        userId: 'wrk-101',
        name: 'Ramesh Kumar',
        employeeId: 'WRK-101',
        email: 'ramesh@hospital.org',
        role: UserRole.worker,
        wardId: 'ICU',
        status: UserStatus.available,
        activeAssignmentId: null,
      );

      await tester.pumpWidget(buildDashboard(user: availableWorker));
      await tester.pumpAndSettle();

      expect(find.text('CleanTrack'), findsOneWidget);
      expect(find.text('HOSPITAL HOUSEKEEPING MANAGEMENT'), findsOneWidget);
      expect(find.text('Worker Dashboard'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('No Tasks Assigned'), findsOneWidget);
      expect(find.text('Available'), findsNothing);
      expect(
        find.text('Single Active Task Rule (PRD 6.3 T01)'),
        findsNothing,
      );
      expect(find.text('CHECK FOR NEW TASKS'), findsOneWidget);
      expect(find.byKey(const Key('workerLogoutButton')), findsOneWidget);
    });

    testWidgets('Tapping MARK TASK COMPLETE transitions to Pending Verification',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestoreService = FirestoreService();
      firestoreService.seedTask(TaskModel(
        taskId: 'task-1',
        wardId: 'ICU',
        title: 'ICU Floor Cleaning',
        description: 'Sanitize and disinfect ICU patient bays',
        createdAt: DateTime.now(),
      ));
      firestoreService.seedAssignment(TaskAssignmentModel(
        assignmentId: 'assign-1',
        taskId: 'task-1',
        workerId: 'wrk-125',
        wardId: 'ICU',
        assignmentNumber: 1,
        attempts: 1,
        deadline: DateTime(2026, 10, 12, 10, 30),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.completed,
      ));

      final worker = UserModel(
        userId: 'wrk-125',
        name: 'Ravi Kumar',
        employeeId: 'WRK-125',
        email: 'ravi@hospital.org',
        role: UserRole.worker,
        wardId: 'ICU',
        status: UserStatus.busy,
        activeAssignmentId: 'assign-1',
      );

      await tester.pumpWidget(buildDashboard(user: worker, firestoreService: firestoreService));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('markTaskCompleteButton')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Task Submitted — Pending Verification'), findsOneWidget);
      expect(find.text('Pending Verification'), findsOneWidget);
    });

    testWidgets('Notifications button opens bottom sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Worker Notifications'), findsOneWidget);
      expect(find.text('Verification Window'), findsOneWidget);
    });

    testWidgets('Tapping CHECK FOR NEW TASKS loads freshly assigned task dynamically',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestoreService = FirestoreService();
      final availableWorker = UserModel(
        userId: 'wrk-101',
        name: 'Ramesh Kumar',
        employeeId: 'WRK-101',
        email: 'ramesh@hospital.org',
        role: UserRole.worker,
        wardId: 'ICU',
        status: UserStatus.available,
        activeAssignmentId: null,
      );

      await tester.pumpWidget(buildDashboard(
        user: availableWorker,
        firestoreService: firestoreService,
      ));
      await tester.pumpAndSettle();

      // Initially in idle state
      expect(find.text('No Tasks Assigned'), findsOneWidget);
      expect(find.text('CHECK FOR NEW TASKS'), findsOneWidget);

      // Supervisor assigns a new task while worker is on this screen
      firestoreService.seedTask(TaskModel(
        taskId: 'task-new',
        wardId: 'ICU',
        title: 'Emergency Disinfection',
        description: 'Complete ward disinfection',
        createdAt: DateTime.now(),
      ));
      firestoreService.seedAssignment(TaskAssignmentModel(
        assignmentId: 'assign-new',
        taskId: 'task-new',
        workerId: 'wrk-101',
        wardId: 'ICU',
        assignmentNumber: 1,
        attempts: 1,
        deadline: DateTime(2026, 10, 13, 14, 0),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.completed,
      ));

      // Worker clicks CHECK FOR NEW TASKS
      await tester.tap(find.text('CHECK FOR NEW TASKS'));
      await tester.pumpAndSettle();

      // New task should now be loaded dynamically!
      expect(find.text('No Tasks Assigned'), findsNothing);
      expect(find.text('Emergency Disinfection'), findsOneWidget);
      expect(find.text('New task loaded: Emergency Disinfection'), findsOneWidget);
    });
  });
}
