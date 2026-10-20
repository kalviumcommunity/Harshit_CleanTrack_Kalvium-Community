import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/models/task_model.dart';
import 'package:cleantrack/models/task_assignment_model.dart';
import 'package:cleantrack/services/firestore_service.dart';
import 'package:cleantrack/screens/worker_dashboard_screen.dart';

void main() {
  group('WorkerDashboardScreen Tests', () {
    setUp(() {
      FirestoreService().clearAllData();
    });

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
        deadline: DateTime(DateTime.now().year + 1, 10, 12, 10, 30),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.pending,
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
      expect(find.text('Pending'), findsOneWidget);
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
        deadline: DateTime(DateTime.now().year + 1, 10, 12, 10, 30),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.pending,
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
        deadline: DateTime(DateTime.now().year + 1, 10, 13, 14, 0),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.pending,
      ));

      // Worker clicks CHECK FOR NEW TASKS
      await tester.tap(find.text('CHECK FOR NEW TASKS'));
      await tester.pumpAndSettle();

      // New task should now be loaded dynamically!
      expect(find.text('No Tasks Assigned'), findsNothing);
      expect(find.text('Emergency Disinfection'), findsOneWidget);
      expect(find.text('New task loaded: Emergency Disinfection'), findsOneWidget);
    });

    testWidgets('Task verification by supervisor immediately reflects on worker dashboard without refreshing',
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
        description: 'Sanitize ICU patient bays',
        createdAt: DateTime.now(),
      ));
      firestoreService.seedAssignment(TaskAssignmentModel(
        assignmentId: 'assign-1',
        taskId: 'task-1',
        workerId: 'wrk-125',
        wardId: 'ICU',
        assignmentNumber: 1,
        attempts: 0,
        deadline: DateTime.now().add(const Duration(hours: 24)),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.pendingVerification,
        completedAt: DateTime.now(),
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
      firestoreService.seedWorker(worker);

      await tester.pumpWidget(buildDashboard(user: worker, firestoreService: firestoreService));
      await tester.pumpAndSettle();

      // Worker dashboard is displaying the active pending verification task
      expect(find.text('ICU Floor Cleaning'), findsOneWidget);
      expect(find.text('Pending Verification'), findsOneWidget);

      // Supervisor verifies the task
      await firestoreService.verifyTaskAssignment(
        assignmentId: 'assign-1',
        taskId: 'task-1',
        workerId: 'wrk-125',
      );

      // Pump to trigger stream listener without any user interaction or refresh
      await tester.pumpAndSettle();

      // Worker dashboard immediately updates in real-time to idle state!
      expect(find.text('ICU Floor Cleaning'), findsNothing);
      expect(find.text('No Tasks Assigned'), findsOneWidget);
    });

    testWidgets('3rd rejection immediately suspends worker and displays SuspensionScreen on worker dashboard without refreshing',
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
        description: 'Sanitize ICU patient bays',
        createdAt: DateTime.now(),
      ));
      firestoreService.seedAssignment(TaskAssignmentModel(
        assignmentId: 'assign-1',
        taskId: 'task-1',
        workerId: 'wrk-125',
        wardId: 'ICU',
        assignmentNumber: 1,
        attempts: 2, // 2 previous attempts, next rejection will be 3rd!
        deadline: DateTime.now().add(const Duration(hours: 24)),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.pendingVerification,
        completedAt: DateTime.now(),
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
      firestoreService.seedWorker(worker);

      await tester.pumpWidget(buildDashboard(user: worker, firestoreService: firestoreService));
      await tester.pumpAndSettle();

      expect(find.text('ICU Floor Cleaning'), findsOneWidget);

      // Supervisor rejects for the 3rd time
      await firestoreService.rejectTaskAssignment(
        assignmentId: 'assign-1',
        taskId: 'task-1',
        workerId: 'wrk-125',
        currentAttempts: 2,
      );

      // Worker dashboard immediately receives user suspension update and rebuilds without manual refresh
      await tester.pumpAndSettle();

      // SuspensionScreen is immediately shown
      expect(find.text('Account Suspended'), findsOneWidget);
      expect(find.byKey(const Key('suspensionLogoutButton')), findsOneWidget);
      expect(find.text('ICU Floor Cleaning'), findsNothing);
    });

    testWidgets('1st rejection immediately updates task back to pending with updated failed attempts without refreshing',
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
        description: 'Sanitize ICU patient bays',
        createdAt: DateTime.now(),
      ));
      firestoreService.seedAssignment(TaskAssignmentModel(
        assignmentId: 'assign-1',
        taskId: 'task-1',
        workerId: 'wrk-125',
        wardId: 'ICU',
        assignmentNumber: 1,
        attempts: 0,
        deadline: DateTime.now().add(const Duration(hours: 24)),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.pendingVerification,
        completedAt: DateTime.now(),
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
      firestoreService.seedWorker(worker);

      await tester.pumpWidget(buildDashboard(user: worker, firestoreService: firestoreService));
      await tester.pumpAndSettle();

      expect(find.text('Pending Verification'), findsOneWidget);

      // Supervisor rejects for 1st time
      await firestoreService.rejectTaskAssignment(
        assignmentId: 'assign-1',
        taskId: 'task-1',
        workerId: 'wrk-125',
        currentAttempts: 0,
      );

      // Stream updates real-time
      await tester.pumpAndSettle();

      // Task is back to Pending with Failed Attempts: 1 / 3 and MARK TASK COMPLETE button visible
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Failed Attempts: 1 / 3'), findsOneWidget);
      expect(find.byKey(const Key('markTaskCompleteButton')), findsOneWidget);
    });

    testWidgets(
        'When task deadline expires, worker is immediately suspended and SuspensionScreen is displayed without refreshing (PRD SU01)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestoreService = FirestoreService();
      firestoreService.seedTask(TaskModel(
        taskId: 'task-exp',
        wardId: 'ICU',
        title: 'Emergency Floor Sterilization',
        description: 'Sanitize ICU patient bays',
        createdAt: DateTime.now(),
      ));

      // Deadline is 2 seconds in the future
      final nearDeadline = DateTime.now().add(const Duration(seconds: 2));
      firestoreService.seedAssignment(TaskAssignmentModel(
        assignmentId: 'assign-exp',
        taskId: 'task-exp',
        workerId: 'wrk-125',
        wardId: 'ICU',
        assignmentNumber: 1,
        attempts: 0,
        deadline: nearDeadline,
        assignedAt: DateTime.now(),
        status: AssignmentStatus.pending,
      ));

      final worker = UserModel(
        userId: 'wrk-125',
        name: 'Ravi Kumar',
        employeeId: 'WRK-125',
        email: 'ravi@hospital.org',
        role: UserRole.worker,
        wardId: 'ICU',
        status: UserStatus.busy,
        activeAssignmentId: 'assign-exp',
      );
      firestoreService.seedWorker(worker);

      await tester.pumpWidget(buildDashboard(user: worker, firestoreService: firestoreService));
      await tester.pumpAndSettle();

      // Initially active task is visible
      expect(find.text('Emergency Floor Sterilization'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Account Suspended'), findsNothing);

      // Advance time past the deadline (3 seconds)
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Worker is immediately suspended and SuspensionScreen is shown without any manual refresh!
      expect(find.text('Emergency Floor Sterilization'), findsNothing);
      expect(find.text('Account Suspended'), findsOneWidget);
      expect(find.textContaining('Access will be restored on:'), findsOneWidget);
      expect(find.byKey(const Key('suspensionDurationBox')), findsOneWidget);
      expect(find.byKey(const Key('suspensionLogoutButton')), findsOneWidget);

      // Verify backend state
      final updatedWorker = await firestoreService.getUserProfile('wrk-125');
      expect(updatedWorker?.status, UserStatus.suspended);
      expect(updatedWorker?.suspendedUntil, isNotNull);
      final updatedAssignment = await firestoreService.getAssignment('assign-exp');
      expect(updatedAssignment?.status, AssignmentStatus.notCompleted);
    });

    testWidgets(
        'SuspensionScreen displays Account Suspended and dashboard access restoration time upon 3rd rejection',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestoreService = FirestoreService();
      firestoreService.seedTask(TaskModel(
        taskId: 'task-rej3',
        wardId: 'ICU',
        title: 'Critical Disinfection',
        description: 'Sanitize ICU patient bays',
        createdAt: DateTime.now(),
      ));

      firestoreService.seedAssignment(TaskAssignmentModel(
        assignmentId: 'assign-rej3',
        taskId: 'task-rej3',
        workerId: 'wrk-125',
        wardId: 'ICU',
        assignmentNumber: 1,
        attempts: 2,
        deadline: DateTime.now().add(const Duration(hours: 10)),
        assignedAt: DateTime.now(),
        status: AssignmentStatus.pendingVerification,
        completedAt: DateTime.now(),
      ));

      final worker = UserModel(
        userId: 'wrk-125',
        name: 'Ravi Kumar',
        employeeId: 'WRK-125',
        email: 'ravi@hospital.org',
        role: UserRole.worker,
        wardId: 'ICU',
        status: UserStatus.busy,
        activeAssignmentId: 'assign-rej3',
      );
      firestoreService.seedWorker(worker);

      await tester.pumpWidget(buildDashboard(user: worker, firestoreService: firestoreService));
      await tester.pumpAndSettle();

      // Supervisor rejects for 3rd time
      await firestoreService.rejectTaskAssignment(
        assignmentId: 'assign-rej3',
        taskId: 'task-rej3',
        workerId: 'wrk-125',
        currentAttempts: 2,
      );

      await tester.pumpAndSettle();

      // Immediate suspension screen
      expect(find.text('Account Suspended'), findsOneWidget);
      expect(find.textContaining('Access will be restored on:'), findsOneWidget);
      expect(find.byKey(const Key('suspensionDurationBox')), findsOneWidget);
      expect(find.byKey(const Key('suspensionLogoutButton')), findsOneWidget);

      final updatedWorker = await firestoreService.getUserProfile('wrk-125');
      expect(updatedWorker?.status, UserStatus.suspended);
      expect(updatedWorker?.suspendedUntil, isNotNull);
    });

    testWidgets(
        'When 1-day suspension period ends, suspension is automatically revoked without having to refresh',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestoreService = FirestoreService();
      // Suspended with 2 seconds remaining
      final worker = UserModel(
        userId: 'wrk-125',
        name: 'Ravi Kumar',
        employeeId: 'WRK-125',
        email: 'ravi@hospital.org',
        role: UserRole.worker,
        wardId: 'ICU',
        status: UserStatus.suspended,
        suspendedUntil: DateTime.now().add(const Duration(seconds: 2)),
      );
      firestoreService.seedWorker(worker);

      await tester.pumpWidget(buildDashboard(user: worker, firestoreService: firestoreService));
      await tester.pumpAndSettle();

      // Initially displays Account Suspended
      expect(find.text('Account Suspended'), findsOneWidget);
      expect(find.text('No Tasks Assigned'), findsNothing);

      // Fast-forward past the suspension period (3 seconds)
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Suspension is automatically revoked without refreshing the screen!
      expect(find.text('Account Suspended'), findsNothing);
      expect(find.text('No Tasks Assigned'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);

      final updated = await firestoreService.getUserProfile('wrk-125');
      expect(updated?.status, UserStatus.available);
      expect(updated?.suspendedUntil, isNull);
    });
  });
}

