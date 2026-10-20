import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/supervisor_pending_verification_screen.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/models/ward_model.dart';
import 'package:cleantrack/models/task_model.dart';
import 'package:cleantrack/models/task_assignment_model.dart';
import 'package:cleantrack/services/auth_service.dart';
import 'package:cleantrack/services/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testSupervisor = UserModel(
    userId: 'sup-101',
    name: 'Rajesh Kumar',
    employeeId: 'SUP-001',
    email: 'rajesh.kumar@hospital.org',
    role: UserRole.supervisor,
    status: UserStatus.assigned,
    wardId: 'ward-icu',
  );

  final testWard = WardModel(
    wardId: 'ward-icu',
    name: 'ICU',
    supervisorId: 'sup-101',
  );

  final worker1 = UserModel(
    userId: 'wrk-125',
    name: 'Ravi Kumar',
    employeeId: 'WRK-125',
    email: 'ravi.kumar@hospital.org',
    role: UserRole.worker,
    status: UserStatus.busy,
    wardId: 'ward-icu',
    activeAssignmentId: 'assign-1',
  );

  final worker2 = UserModel(
    userId: 'wrk-126',
    name: 'Priya Sharma',
    employeeId: 'WRK-126',
    email: 'priya.sharma@hospital.org',
    role: UserRole.worker,
    status: UserStatus.busy,
    wardId: 'ward-icu',
    activeAssignmentId: 'assign-2',
  );

  final availableWorker = UserModel(
    userId: 'wrk-127',
    name: 'Aman Singh',
    employeeId: 'WRK-127',
    email: 'aman.singh@hospital.org',
    role: UserRole.worker,
    status: UserStatus.available,
    wardId: 'ward-icu',
  );

  late FirestoreService firestoreService;

  setUp(() {
    AuthService().clearUsers();
    firestoreService = FirestoreService();
    firestoreService.clearAllData();
    firestoreService.seedWard(testWard);
    firestoreService.seedWorker(worker1);
    firestoreService.seedWorker(worker2);
    firestoreService.seedWorker(availableWorker);
  });

  Widget createPendingVerificationScreen({
    UserModel? user,
    WardModel? ward,
  }) {
    return MaterialApp(
      home: SupervisorPendingVerificationScreen(
        user: user ?? testSupervisor,
        ward: ward ?? testWard,
        firestoreService: firestoreService,
      ),
    );
  }

  testWidgets('Renders Pending Verification screen layout matching mockup', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    firestoreService.seedTask(TaskModel(
      taskId: 'task-1',
      wardId: 'ward-icu',
      title: 'ICU Floor Cleaning',
      description: 'Sanitize ICU patient floor',
      createdAt: DateTime.now(),
    ));

    // Completed 10 minutes ago, well within the 1-hour auto-verify window
    final completedTime = DateTime.now().subtract(const Duration(minutes: 10));
    firestoreService.seedAssignment(TaskAssignmentModel(
      assignmentId: 'assign-1',
      taskId: 'task-1',
      workerId: 'wrk-125',
      wardId: 'ward-icu',
      assignmentNumber: 1,
      attempts: 1,
      deadline: completedTime.add(const Duration(hours: 24)),
      assignedAt: completedTime.subtract(const Duration(hours: 2)),
      completedAt: completedTime,
      status: AssignmentStatus.pendingVerification,
    ));

    await tester.pumpWidget(createPendingVerificationScreen());
    await tester.pumpAndSettle();

    // 1. App Bar Header
    expect(find.text('Pending Verification'), findsOneWidget);
    expect(find.byKey(const Key('pendingVerificationBackButton')), findsOneWidget);
    expect(find.byKey(const Key('pendingVerificationBellButton')), findsOneWidget);
    expect(find.text('RK'), findsOneWidget); // Rajesh Kumar initials

    // 2. Subheader Ward
    expect(find.text('Ward: ICU'), findsOneWidget);

    // 3. Auto-Verification Protocol Box
    expect(find.text('Auto-Verification Protocol'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('If no action is taken within 1 hour'),
      ),
      findsOneWidget,
    );

    // 4. Task Card
    expect(find.text('ICU Floor Cleaning'), findsOneWidget);
    expect(find.text('Ravi Kumar (WRK-125)'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('DEADLINE'), findsOneWidget);
    expect(find.text('Failed Attempts: 1 / 3'), findsOneWidget);

    // Verify & Reject buttons
    expect(find.text('VERIFY'), findsOneWidget);
    expect(find.text('REJECT / FAILED'), findsOneWidget);
  });

  testWidgets('Renders multiple task cards matching mockup with different attempt counts', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    firestoreService.seedTask(TaskModel(
      taskId: 'task-1',
      wardId: 'ward-icu',
      title: 'ICU Floor Cleaning',
      description: 'Sanitize ICU patient floor',
      createdAt: DateTime.now(),
    ));
    firestoreService.seedTask(TaskModel(
      taskId: 'task-2',
      wardId: 'ward-icu',
      title: 'ICU Bed Cleaning',
      description: 'Disinfect ICU beds',
      createdAt: DateTime.now(),
    ));

    final recentTime = DateTime.now().subtract(const Duration(minutes: 15));

    firestoreService.seedAssignment(TaskAssignmentModel(
      assignmentId: 'assign-1',
      taskId: 'task-1',
      workerId: 'wrk-125',
      wardId: 'ward-icu',
      assignmentNumber: 1,
      attempts: 1,
      deadline: recentTime.add(const Duration(hours: 24)),
      completedAt: recentTime,
      status: AssignmentStatus.pendingVerification,
    ));

    firestoreService.seedAssignment(TaskAssignmentModel(
      assignmentId: 'assign-2',
      taskId: 'task-2',
      workerId: 'wrk-126',
      wardId: 'ward-icu',
      assignmentNumber: 1,
      attempts: 2,
      deadline: recentTime.add(const Duration(hours: 24)),
      completedAt: recentTime.subtract(const Duration(minutes: 5)),
      status: AssignmentStatus.pendingVerification,
    ));

    await tester.pumpWidget(createPendingVerificationScreen());
    await tester.pumpAndSettle();

    expect(find.text('ICU Floor Cleaning'), findsOneWidget);
    expect(find.text('Ravi Kumar (WRK-125)'), findsOneWidget);
    expect(find.text('Failed Attempts: 1 / 3'), findsOneWidget);

    expect(find.text('ICU Bed Cleaning'), findsOneWidget);
    expect(find.text('Priya Sharma (WRK-126)'), findsOneWidget);
    expect(find.text('Failed Attempts: 2 / 3'), findsOneWidget);

    expect(find.text('VERIFY'), findsNWidgets(2));
    expect(find.text('REJECT / FAILED'), findsNWidgets(2));
  });

  testWidgets('Tapping VERIFY approves task and transitions assignment to verified', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    firestoreService.seedTask(TaskModel(
      taskId: 'task-1',
      wardId: 'ward-icu',
      title: 'ICU Floor Cleaning',
      description: 'Sanitize ICU patient floor',
      createdAt: DateTime.now(),
    ));

    final recentTime = DateTime.now().subtract(const Duration(minutes: 5));

    firestoreService.seedAssignment(TaskAssignmentModel(
      assignmentId: 'assign-1',
      taskId: 'task-1',
      workerId: 'wrk-125',
      wardId: 'ward-icu',
      assignmentNumber: 1,
      attempts: 0,
      deadline: recentTime.add(const Duration(hours: 24)),
      completedAt: recentTime,
      status: AssignmentStatus.pendingVerification,
    ));

    await tester.pumpWidget(createPendingVerificationScreen());
    await tester.pumpAndSettle();

    final verifyButton = find.byKey(const Key('verifyButton_assign-1'));
    expect(verifyButton, findsOneWidget);

    await tester.tap(verifyButton);
    await tester.pumpAndSettle();

    // Assignment should be verified in firestore
    final updatedAssignment = firestoreService.inMemoryAssignments.firstWhere((a) => a.assignmentId == 'assign-1');
    expect(updatedAssignment.status, AssignmentStatus.verified);

    // Worker status should be back to available
    final updatedWorker = await firestoreService.getUserProfile('wrk-125');
    expect(updatedWorker?.status, UserStatus.available);
    expect(updatedWorker?.activeAssignmentId, isNull);

    // Task is removed from pending verification screen
    expect(find.text('No Tasks Pending Verification'), findsOneWidget);
  });

  testWidgets('1st rejection increments attempts to 1 and moves task back to pending', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    firestoreService.seedTask(TaskModel(
      taskId: 'task-1',
      wardId: 'ward-icu',
      title: 'ICU Floor Cleaning',
      description: 'Sanitize ICU patient floor',
      createdAt: DateTime.now(),
    ));

    final recentTime = DateTime.now().subtract(const Duration(minutes: 5));

    firestoreService.seedAssignment(TaskAssignmentModel(
      assignmentId: 'assign-1',
      taskId: 'task-1',
      workerId: 'wrk-125',
      wardId: 'ward-icu',
      assignmentNumber: 1,
      attempts: 0,
      deadline: recentTime.add(const Duration(hours: 24)),
      completedAt: recentTime,
      status: AssignmentStatus.pendingVerification,
    ));

    await tester.pumpWidget(createPendingVerificationScreen());
    await tester.pumpAndSettle();

    final rejectButton = find.byKey(const Key('rejectButton_assign-1'));
    expect(rejectButton, findsOneWidget);

    await tester.tap(rejectButton);
    await tester.pumpAndSettle();

    // Assignment should be reset back to pending with attempts = 1
    final updatedAssignment = firestoreService.inMemoryAssignments.firstWhere((a) => a.assignmentId == 'assign-1');
    expect(updatedAssignment.status, AssignmentStatus.pending);
    expect(updatedAssignment.attempts, 1);
    expect(updatedAssignment.completedAt, isNull);

    // Worker remains busy with active assignment
    final updatedWorker = await firestoreService.getUserProfile('wrk-125');
    expect(updatedWorker?.status, UserStatus.busy);
    expect(updatedWorker?.activeAssignmentId, 'assign-1');

    // No supervisor feedback dialog was presented
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('2nd rejection increments attempts to 2 and moves task back to pending', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    firestoreService.seedTask(TaskModel(
      taskId: 'task-1',
      wardId: 'ward-icu',
      title: 'ICU Floor Cleaning',
      description: 'Sanitize ICU patient floor',
      createdAt: DateTime.now(),
    ));

    final recentTime = DateTime.now().subtract(const Duration(minutes: 5));

    firestoreService.seedAssignment(TaskAssignmentModel(
      assignmentId: 'assign-1',
      taskId: 'task-1',
      workerId: 'wrk-125',
      wardId: 'ward-icu',
      assignmentNumber: 1,
      attempts: 1,
      deadline: recentTime.add(const Duration(hours: 24)),
      completedAt: recentTime,
      status: AssignmentStatus.pendingVerification,
    ));

    await tester.pumpWidget(createPendingVerificationScreen());
    await tester.pumpAndSettle();

    final rejectButton = find.byKey(const Key('rejectButton_assign-1'));
    await tester.tap(rejectButton);
    await tester.pumpAndSettle();

    final updatedAssignment = firestoreService.inMemoryAssignments.firstWhere((a) => a.assignmentId == 'assign-1');
    expect(updatedAssignment.status, AssignmentStatus.pending);
    expect(updatedAssignment.attempts, 2);
    expect(updatedAssignment.completedAt, isNull);
  });

  testWidgets('3rd rejection instantly suspends worker and displays inline worker dropdown for reassignment', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    firestoreService.seedTask(TaskModel(
      taskId: 'task-1',
      wardId: 'ward-icu',
      title: 'ICU Floor Cleaning',
      description: 'Sanitize ICU patient floor',
      createdAt: DateTime.now(),
    ));

    final recentTime = DateTime.now().subtract(const Duration(minutes: 5));

    firestoreService.seedAssignment(TaskAssignmentModel(
      assignmentId: 'assign-1',
      taskId: 'task-1',
      workerId: 'wrk-125',
      wardId: 'ward-icu',
      assignmentNumber: 1,
      attempts: 2, // currently 2 failed attempts, next rejection will be 3rd!
      deadline: recentTime.add(const Duration(hours: 24)),
      completedAt: recentTime,
      status: AssignmentStatus.pendingVerification,
    ));

    await tester.pumpWidget(createPendingVerificationScreen());
    await tester.pumpAndSettle();

    final rejectButton = find.byKey(const Key('rejectButton_assign-1'));
    await tester.tap(rejectButton);
    await tester.pumpAndSettle();

    // 1. Worker is immediately suspended
    final suspendedWorker = await firestoreService.getUserProfile('wrk-125');
    expect(suspendedWorker?.status, UserStatus.suspended);
    expect(suspendedWorker?.activeAssignmentId, isNull);

    // 2. Old assignment is marked Not Completed with attempts = 3
    final oldAssignment = firestoreService.inMemoryAssignments.firstWhere((a) => a.assignmentId == 'assign-1');
    expect(oldAssignment.status, AssignmentStatus.notCompleted);
    expect(oldAssignment.attempts, 3);

    // 3. Inline reassignment UI is displayed on the screen
    expect(find.byKey(const Key('reassignSection_assign-1')), findsOneWidget);
    expect(find.textContaining('Worker suspended (3 failed attempts'), findsOneWidget);
    expect(find.byKey(const Key('reassignWorkerDropdown_assign-1')), findsOneWidget);

    // 4. Supervisor selects available worker Aman Singh
    await tester.tap(find.byKey(const Key('reassignWorkerDropdown_assign-1')));
    await tester.pumpAndSettle();

    expect(find.text('Aman Singh (WRK-127)').last, findsOneWidget);
    await tester.tap(find.text('Aman Singh (WRK-127)').last);
    await tester.pumpAndSettle();

    // 5. Supervisor taps REASSIGN TASK button
    final reassignButton = find.byKey(const Key('reassignTaskButton_assign-1'));
    expect(reassignButton, findsOneWidget);
    await tester.tap(reassignButton);
    await tester.pumpAndSettle();

    // 6. Verify new assignment created with attempts = 0
    final newWorker = await firestoreService.getUserProfile('wrk-127');
    expect(newWorker?.status, UserStatus.busy);
    expect(newWorker?.activeAssignmentId, isNotNull);

    final newAssignment = firestoreService.inMemoryAssignments.firstWhere(
      (a) => a.assignmentId == newWorker!.activeAssignmentId!,
    );
    expect(newAssignment.workerId, 'wrk-127');
    expect(newAssignment.taskId, 'task-1');
    expect(newAssignment.attempts, 0); // attempts starts from 0 for every worker!
    expect(newAssignment.status, AssignmentStatus.pending);
    expect(newAssignment.assignmentNumber, 2);
  });

  testWidgets('Auto-Verification Protocol automatically marks tasks completed >1h ago as Auto Verified', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    firestoreService.seedTask(TaskModel(
      taskId: 'task-1',
      wardId: 'ward-icu',
      title: 'ICU Floor Cleaning',
      description: 'Sanitize ICU patient floor',
      createdAt: DateTime.now(),
    ));

    // Completed 75 minutes ago (> 1 hour)
    final pastCompletedTime = DateTime.now().subtract(const Duration(minutes: 75));

    firestoreService.seedAssignment(TaskAssignmentModel(
      assignmentId: 'assign-auto',
      taskId: 'task-1',
      workerId: 'wrk-125',
      wardId: 'ward-icu',
      assignmentNumber: 1,
      attempts: 0,
      deadline: pastCompletedTime.add(const Duration(hours: 24)),
      assignedAt: pastCompletedTime.subtract(const Duration(hours: 1)),
      completedAt: pastCompletedTime,
      status: AssignmentStatus.pendingVerification,
    ));

    await tester.pumpWidget(createPendingVerificationScreen());
    await tester.pumpAndSettle();

    // Assignment should be automatically auto-verified
    final autoVerifiedAssignment = firestoreService.inMemoryAssignments.firstWhere((a) => a.assignmentId == 'assign-auto');
    expect(autoVerifiedAssignment.status, AssignmentStatus.autoVerified);

    // Worker status freed to available
    final worker = await firestoreService.getUserProfile('wrk-125');
    expect(worker?.status, UserStatus.available);
    expect(worker?.activeAssignmentId, isNull);

    // Screen displays empty state since task was automatically verified
    expect(find.text('No Tasks Pending Verification'), findsOneWidget);
  });

  testWidgets('Renders empty state cleanly when ward has no pending verification tasks', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createPendingVerificationScreen());
    await tester.pumpAndSettle();

    expect(find.text('Pending Verification'), findsOneWidget);
    expect(find.text('Ward: ICU'), findsOneWidget);
    expect(find.text('Auto-Verification Protocol'), findsOneWidget);
    expect(find.text('No Tasks Pending Verification'), findsOneWidget);
    expect(
      find.text('All completed housekeeping tasks in this ward have been verified.'),
      findsOneWidget,
    );
  });
}

