import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/supervisor_worker_list_screen.dart';
import 'package:cleantrack/screens/supervisor_assign_task_screen.dart';
import 'package:cleantrack/screens/login_screen.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/models/ward_model.dart';
import 'package:cleantrack/models/task_model.dart';
import 'package:cleantrack/models/task_assignment_model.dart';
import 'package:cleantrack/services/auth_service.dart';
import 'package:cleantrack/services/firestore_service.dart';
import 'package:cleantrack/widgets/user_avatar.dart';

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

  final sampleWorkers = [
    UserModel(
      userId: 'wrk-125',
      name: 'Ravi Kumar',
      employeeId: 'WRK-125',
      email: 'ravi.kumar@hospital.org',
      role: UserRole.worker,
      status: UserStatus.available,
      wardId: 'ward-icu',
    ),
    UserModel(
      userId: 'wrk-126',
      name: 'Aman Singh',
      employeeId: 'WRK-126',
      email: 'aman.singh@hospital.org',
      role: UserRole.worker,
      status: UserStatus.busy,
      wardId: 'ward-icu',
    ),
    UserModel(
      userId: 'wrk-127',
      name: 'Sandeep Kumar',
      employeeId: 'WRK-127',
      email: 'sandeep.kumar@hospital.org',
      role: UserRole.worker,
      status: UserStatus.suspended,
      wardId: 'ward-icu',
    ),
    UserModel(
      userId: 'wrk-132',
      name: 'Sunil Joshi',
      employeeId: 'WRK-132',
      email: 'sunil.joshi@hospital.org',
      role: UserRole.worker,
      status: UserStatus.available,
      wardId: 'ward-icu',
    ),
  ];

  late FirestoreService firestoreService;

  setUp(() {
    AuthService().clearUsers();
    firestoreService = FirestoreService();
    firestoreService.clearAllData();
    firestoreService.seedWard(testWard);
  });

  void seedMockupWorkers() {
    for (final worker in sampleWorkers) {
      firestoreService.seedWorker(worker);
    }
    // Seed task for busy worker Aman Singh
    firestoreService.seedTask(TaskModel(
      taskId: 'task-waste-01',
      wardId: 'ward-icu',
      title: 'Waste Collection',
      description: 'Collect medical waste',
      createdAt: DateTime.now(),
    ));
    firestoreService.seedAssignment(TaskAssignmentModel(
      assignmentId: 'assign-waste-01',
      taskId: 'task-waste-01',
      workerId: 'wrk-126',
      wardId: 'ward-icu',
      deadline: DateTime.now().add(const Duration(hours: 2)),
      assignedAt: DateTime.now(),
      status: AssignmentStatus.pendingVerification,
    ));
  }

  Widget createWorkerListScreen({
    UserModel? user,
    WardModel? ward,
  }) {
    return MaterialApp(
      home: SupervisorWorkerListScreen(
        user: user ?? testSupervisor,
        ward: ward ?? testWard,
        firestoreService: firestoreService,
      ),
    );
  }

  group('UserAvatar & Initials Unit Tests', () {
    test('getUserInitials extracts initials accurately without hardcoded fallbacks', () {
      expect(getUserInitials('Ravi Kumar'), 'RK');
      expect(getUserInitials('Aman Singh'), 'AS');
      expect(getUserInitials('Sandeep'), 'S');
      expect(getUserInitials('Dr. Rajesh Kumar'), 'DR');
      expect(getUserInitials(''), '');
      expect(getUserInitials('   '), '');
      expect(getUserInitials(null), '');
    });

    testWidgets('UserAvatar renders dynamically based on name', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(name: 'Sunil Joshi'),
          ),
        ),
      );
      expect(find.text('SJ'), findsOneWidget);
    });
  });

  group('SupervisorWorkerListScreen Widget Tests', () {
    testWidgets('Displays Empty State cleanly when ward has no workers', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWorkerListScreen());
      await tester.pumpAndSettle();

      expect(find.text('No Workers Assigned'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // Total Staff: 0
    });

    testWidgets('Worker List Screen matches design mockup dynamically with seeded data', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      seedMockupWorkers();

      await tester.pumpWidget(createWorkerListScreen());
      await tester.pumpAndSettle();

      // 1. App Bar
      expect(find.text('Worker List'), findsOneWidget);
      expect(find.byKey(const Key('workerListBackButton')), findsOneWidget);
      expect(find.byKey(const Key('workerListNotificationButton')), findsOneWidget);
      expect(find.text('RK'), findsWidgets); // Rajesh Kumar supervisor initials and Ravi Kumar worker

      // 2. Ward Pill & Total Staff Pill
      expect(find.text('Ward : '), findsOneWidget);
      expect(find.text('ICU'), findsOneWidget);
      expect(find.text('Total Staff'), findsOneWidget);
      expect(find.text('4'), findsWidgets);

      // 3. Worker 1: Ravi Kumar (Available)
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('WRK-125'), findsOneWidget);
      expect(find.text('Ready for assignment'), findsNWidgets(2)); // Ravi Kumar & Sunil Joshi
      expect(find.text('ASSIGN TASK'), findsNWidgets(2)); // Ravi Kumar & Sunil Joshi

      // 4. Worker 2: Aman Singh (Busy)
      expect(find.text('Aman Singh'), findsOneWidget);
      expect(find.text('WRK-126'), findsOneWidget);
      expect(find.text('Busy'), findsOneWidget);
      expect(find.text('Current Task'), findsOneWidget);
      expect(find.text('Waste Collection'), findsOneWidget);

      // 5. Worker 3: Sandeep Kumar (Suspended)
      expect(find.text('Sandeep Kumar'), findsOneWidget);
      expect(find.text('WRK-127'), findsOneWidget);
      expect(find.text('Suspended'), findsOneWidget);
      expect(find.text('Suspended - Restricted from task assignment'), findsOneWidget);

      // 6. Worker 4: Sunil Joshi (Available)
      expect(find.text('Sunil Joshi'), findsOneWidget);
      expect(find.text('WRK-132'), findsOneWidget);
      expect(find.text('Available'), findsNWidgets(2)); // Ravi Kumar & Sunil Joshi
    });

    testWidgets('Tapping ASSIGN TASK navigates to SupervisorAssignTaskScreen with selected worker', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      seedMockupWorkers();

      await tester.pumpWidget(createWorkerListScreen());
      await tester.pumpAndSettle();

      final assignButton = find.byKey(const Key('assignTaskButton_wrk-125'));
      expect(assignButton, findsOneWidget);

      await tester.tap(assignButton);
      await tester.pumpAndSettle();

      expect(find.byType(SupervisorAssignTaskScreen), findsOneWidget);
    });

    testWidgets('Tapping Back Button pops the screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SupervisorWorkerListScreen(
                  user: testSupervisor,
                  ward: testWard,
                  firestoreService: firestoreService,
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SupervisorWorkerListScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('workerListBackButton')));
      await tester.pumpAndSettle();

      expect(find.byType(SupervisorWorkerListScreen), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('Supervisor profile avatar PopupMenu shows details and logs out', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWorkerListScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('workerListProfileButton')));
      await tester.pumpAndSettle();

      expect(find.text('Rajesh Kumar'), findsOneWidget);
      expect(find.text('rajesh.kumar@hospital.org'), findsOneWidget);
      expect(find.text('LOG OUT'), findsOneWidget);

      await tester.tap(find.text('LOG OUT'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Worker list displays Available workers on top, then Busy workers, then Suspended workers', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      seedMockupWorkers();

      await tester.pumpWidget(createWorkerListScreen());
      await tester.pumpAndSettle();

      final raviPos = tester.getTopLeft(find.text('Ravi Kumar'));
      final sunilPos = tester.getTopLeft(find.text('Sunil Joshi'));
      final amanPos = tester.getTopLeft(find.text('Aman Singh'));
      final sandeepPos = tester.getTopLeft(find.text('Sandeep Kumar'));

      // Both Ravi Kumar and Sunil Joshi are Available, sorted alphabetically
      expect(raviPos.dy < sunilPos.dy, isTrue, reason: 'Ravi Kumar (available) should appear above Sunil Joshi (available)');
      // Available workers appear above Busy workers
      expect(sunilPos.dy < amanPos.dy, isTrue, reason: 'Sunil Joshi (available) should appear above Aman Singh (busy)');
      // Busy workers appear above Suspended workers
      expect(amanPos.dy < sandeepPos.dy, isTrue, reason: 'Aman Singh (busy) should appear above Sandeep Kumar (suspended)');
    });
  });
}
