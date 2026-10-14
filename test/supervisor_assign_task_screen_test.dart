import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/supervisor_assign_task_screen.dart';
import 'package:cleantrack/screens/login_screen.dart';
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
    name: 'ICU Ward',
    supervisorId: 'sup-101',
  );

  final availableWorker = UserModel(
    userId: 'wrk-125',
    name: 'Ravi Kumar',
    employeeId: 'WRK-125',
    email: 'ravi.kumar@hospital.org',
    role: UserRole.worker,
    status: UserStatus.available,
    wardId: 'ward-icu',
  );

  final busyWorker = UserModel(
    userId: 'wrk-126',
    name: 'Aman Singh',
    employeeId: 'WRK-126',
    email: 'aman.singh@hospital.org',
    role: UserRole.worker,
    status: UserStatus.busy,
    wardId: 'ward-icu',
  );

  final suspendedWorker = UserModel(
    userId: 'wrk-127',
    name: 'Sandeep Kumar',
    employeeId: 'WRK-127',
    email: 'sandeep.kumar@hospital.org',
    role: UserRole.worker,
    status: UserStatus.suspended,
    wardId: 'ward-icu',
  );

  late FirestoreService firestoreService;

  setUp(() {
    AuthService().clearUsers();
    firestoreService = FirestoreService();
    firestoreService.clearAllData();
    firestoreService.seedWard(testWard);
    firestoreService.seedWorker(availableWorker);
    firestoreService.seedWorker(busyWorker);
    firestoreService.seedWorker(suspendedWorker);
  });

  Widget createAssignTaskScreen({
    UserModel? selectedWorker,
    UserModel? user,
    WardModel? ward,
  }) {
    return MaterialApp(
      home: SupervisorAssignTaskScreen(
        selectedWorker: selectedWorker,
        user: user ?? testSupervisor,
        ward: ward ?? testWard,
        firestoreService: firestoreService,
      ),
    );
  }

  testWidgets('Assign Task Screen renders all sections matching mockup', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createAssignTaskScreen(selectedWorker: availableWorker));
    await tester.pumpAndSettle();

    // 1. App Bar Header
    expect(find.text('Assign Task'), findsOneWidget);
    expect(find.byKey(const Key('assignTaskBackButton')), findsOneWidget);
    expect(find.byKey(const Key('assignTaskNotificationButton')), findsOneWidget);
    expect(find.text('RK'), findsWidgets); // Rajesh Kumar supervisor & Ravi Kumar worker initials

    // 2. Available Worker Section
    expect(find.text('Available Worker'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('ID: WRK-125'), findsOneWidget);

    expect(find.text('Aman Singh'), findsOneWidget);
    expect(find.text('ID: WRK-126'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

    expect(find.text('Sandeep Kumar'), findsOneWidget);
    expect(find.text('ID: WRK-127'), findsOneWidget);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);

    // 3. Task Input Section
    expect(find.text('Task'), findsOneWidget);
    expect(find.byKey(const Key('taskTitleInput')), findsOneWidget);
    expect(find.text('Enter task title'), findsOneWidget);

    // 4. Description Section
    expect(find.text('Description'), findsOneWidget);
    expect(find.byKey(const Key('taskDescriptionInput')), findsOneWidget);
    expect(find.text('Task explanation ...'), findsOneWidget);

    // 5. Deadline Section (Date and Time pickers)
    expect(find.text('Deadline'), findsOneWidget);
    expect(find.byKey(const Key('datePickerTile')), findsOneWidget);
    expect(find.byKey(const Key('deadlinePickerTile')), findsOneWidget);
    expect(find.text('10:30'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);

    // 6. Assign Task Button
    expect(find.byKey(const Key('submitAssignTaskButton')), findsOneWidget);
    expect(find.text('ASSIGN TASK'), findsOneWidget);
  });

  testWidgets('Allows selecting available worker and disables busy/suspended workers', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final anotherAvailable = UserModel(
      userId: 'wrk-132',
      name: 'Sunil Joshi',
      employeeId: 'WRK-132',
      email: 'sunil@hospital.org',
      role: UserRole.worker,
      status: UserStatus.available,
      wardId: 'ward-icu',
    );
    firestoreService.seedWorker(anotherAvailable);

    await tester.pumpWidget(createAssignTaskScreen(selectedWorker: availableWorker));
    await tester.pumpAndSettle();

    // Tap on Sunil Joshi to select him
    await tester.tap(find.byKey(const Key('workerSelectTile_wrk-132')));
    await tester.pumpAndSettle();

    // Tap on busy worker Aman Singh shows feedback SnackBar
    await tester.tap(find.byKey(const Key('workerDisabledTile_wrk-126')));
    await tester.pumpAndSettle();

    expect(find.text('Aman Singh is currently busy with an active task.'), findsOneWidget);
  });

  testWidgets('Submitting task creates assignment in FirestoreService and updates worker status', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createAssignTaskScreen(selectedWorker: availableWorker));
    await tester.pumpAndSettle();

    // Enter task description
    await tester.enterText(find.byKey(const Key('taskDescriptionInput')), 'Disinfect all patient bed rails');
    await tester.pumpAndSettle();

    // Tap ASSIGN TASK
    await tester.tap(find.byKey(const Key('submitAssignTaskButton')));
    await tester.pumpAndSettle();

    // Check worker status updated to busy
    final updatedWorker = await firestoreService.getUserProfile('wrk-125');
    expect(updatedWorker?.status, UserStatus.busy);
    expect(updatedWorker?.activeAssignmentId, isNotNull);
  });

  testWidgets('Validation error shown when description is missing', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createAssignTaskScreen(selectedWorker: availableWorker));
    await tester.pumpAndSettle();

    // Description is empty by default, tap ASSIGN TASK
    await tester.tap(find.byKey(const Key('submitAssignTaskButton')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter task instructions in the description field.'), findsOneWidget);
  });

  testWidgets('Supervisor profile avatar PopupMenu shows details and logs out', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createAssignTaskScreen(selectedWorker: availableWorker));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assignTaskProfileButton')));
    await tester.pumpAndSettle();

    expect(find.text('Rajesh Kumar'), findsOneWidget);
    expect(find.text('rajesh.kumar@hospital.org'), findsOneWidget);
    expect(find.text('LOG OUT'), findsOneWidget);

    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Supervisor can pick deadline date and time, and task is created with multi-day deadline', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createAssignTaskScreen(selectedWorker: availableWorker));
    await tester.pumpAndSettle();

    // Verify date picker tile is visible
    expect(find.byKey(const Key('datePickerTile')), findsOneWidget);

    // Tap on date picker tile opens date picker dialog
    await tester.tap(find.byKey(const Key('datePickerTile')));
    await tester.pumpAndSettle();

    // Confirm dialog is present and tap OK
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Enter task title & description
    await tester.enterText(find.byKey(const Key('taskTitleInput')), 'ICU Floor Cleaning');
    await tester.enterText(find.byKey(const Key('taskDescriptionInput')), 'Deep cleaning after patient discharge');
    await tester.pumpAndSettle();

    // Tap ASSIGN TASK
    await tester.tap(find.byKey(const Key('submitAssignTaskButton')));
    await tester.pumpAndSettle();

    // Verify task and assignment were created in FirestoreService
    expect(firestoreService.inMemoryTasks.isNotEmpty, isTrue);
    expect(firestoreService.inMemoryAssignments.isNotEmpty, isTrue);

    final createdTask = firestoreService.inMemoryTasks.first;
    final createdAssignment = firestoreService.inMemoryAssignments.first;
    expect(createdTask.status, TaskStatus.open);
    expect(createdAssignment.status, AssignmentStatus.pending);
    expect(createdAssignment.deadline, isNotNull);
  });

  testWidgets('Task status transitions to Closed when task assignment is verified', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createAssignTaskScreen(selectedWorker: availableWorker));
    await tester.pumpAndSettle();

    // Enter title & description and assign task
    await tester.enterText(find.byKey(const Key('taskTitleInput')), 'OR Sanitization');
    await tester.enterText(find.byKey(const Key('taskDescriptionInput')), 'Sanitize operating room fixtures');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submitAssignTaskButton')));
    await tester.pumpAndSettle();

    final task = firestoreService.inMemoryTasks.first;
    final assignment = firestoreService.inMemoryAssignments.first;

    // Verify initial states
    expect(task.status, TaskStatus.open);
    expect(assignment.status, AssignmentStatus.pending);

    // Supervisor verifies the assignment
    final success = await firestoreService.verifyTaskAssignment(
      assignmentId: assignment.assignmentId,
      taskId: task.taskId,
      workerId: availableWorker.userId,
    );
    expect(success, isTrue);

    // Verify parent task status is now Closed
    final closedTask = await firestoreService.getTask(task.taskId);
    expect(closedTask?.status, TaskStatus.closed);

    // Verify assignment status is Verified
    final verifiedAssignment = firestoreService.inMemoryAssignments.firstWhere((a) => a.assignmentId == assignment.assignmentId);
    expect(verifiedAssignment.status, AssignmentStatus.verified);
    expect(verifiedAssignment.verifiedAt, isNotNull);

    // Verify worker is freed back to Available
    final freedWorker = await firestoreService.getUserProfile(availableWorker.userId);
    expect(freedWorker?.status, UserStatus.available);
    expect(freedWorker?.activeAssignmentId, isNull);
  });

  testWidgets('Task status transitions to Closed when task assignment is auto-verified after 1 hour', (WidgetTester tester) async {
    final now = DateTime.now();
    final task = TaskModel(
      taskId: 'task-auto-01',
      wardId: 'ward-icu',
      title: 'Emergency Sterilization',
      description: 'Sterilize instruments',
      status: TaskStatus.open,
      currentAssignmentId: 'assign-auto-01',
    );
    final assignment = TaskAssignmentModel(
      assignmentId: 'assign-auto-01',
      taskId: 'task-auto-01',
      workerId: availableWorker.userId,
      wardId: 'ward-icu',
      deadline: now.add(const Duration(hours: 2)),
      completedAt: now.subtract(const Duration(minutes: 65)), // completed >1h ago
      status: AssignmentStatus.pendingVerification,
    );
    firestoreService.seedTask(task);
    firestoreService.seedAssignment(assignment);

    // Run auto-verify routine
    await firestoreService.checkAndAutoVerifyAssignments();

    // Verify task is now Closed
    final closedTask = await firestoreService.getTask('task-auto-01');
    expect(closedTask?.status, TaskStatus.closed);

    // Verify assignment is Auto Verified
    final autoVerifiedAssignment = firestoreService.inMemoryAssignments.firstWhere((a) => a.assignmentId == 'assign-auto-01');
    expect(autoVerifiedAssignment.status, AssignmentStatus.autoVerified);
    expect(autoVerifiedAssignment.verifiedAt, isNotNull);
  });
}
