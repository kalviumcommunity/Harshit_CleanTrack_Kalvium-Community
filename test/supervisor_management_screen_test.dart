import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/screens/supervisor_management_screen.dart';
import 'package:cleantrack/services/auth_service.dart';
import 'package:cleantrack/services/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testAdmin = UserModel(
    userId: 'admin-001',
    name: 'Rajesh Kumar',
    employeeId: 'ADM-001',
    email: 'rajesh@cleantrack.org',
    role: UserRole.admin,
    status: UserStatus.available,
  );

  final assignedSupervisor = UserModel(
    userId: 'sup-001',
    name: 'Neha Sharma',
    employeeId: 'SUP-001',
    email: 'neha@hospital.org',
    role: UserRole.supervisor,
    status: UserStatus.assigned,
    wardId: 'ward_icu',
    wardName: 'ICU',
  );

  final pendingSupervisor = UserModel(
    userId: 'sup-002',
    name: 'Pending Supervisor',
    employeeId: 'SUP-002',
    email: 'pending@hospital.org',
    role: UserRole.supervisor,
    status: UserStatus.pending,
    wardId: 'ward_a',
    wardName: 'Ward A',
  );

  Widget createScreen() {
    return MaterialApp(
      home: SupervisorManagementScreen(
        adminUser: testAdmin,
        firestoreService: FirestoreService(),
      ),
    );
  }

  setUp(() {
    FirestoreService().clearAllData();
    AuthService().clearUsers();
  });

  testWidgets('Renders Supervisor Management header with admin controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    expect(find.text('Supervisor Management'), findsOneWidget);
    expect(
      find.byKey(const Key('supervisorManagementBackButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('supervisorManagementNotificationButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('supervisorManagementProfileButton')),
      findsOneWidget,
    );
    expect(find.text('RK'), findsOneWidget);
  });

  testWidgets(
    'Displays only assigned supervisors with dynamic ward and worker data',
    (WidgetTester tester) async {
      final firestoreService = FirestoreService();
      firestoreService.seedWorker(assignedSupervisor);
      firestoreService.seedWorker(pendingSupervisor);
      firestoreService.seedWorker(
        UserModel(
          userId: 'worker-001',
          name: 'Ravi Kumar',
          employeeId: 'WRK-001',
          email: 'ravi@hospital.org',
          role: UserRole.worker,
          status: UserStatus.available,
          wardId: 'ward_icu',
          wardName: 'ICU',
        ),
      );

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      expect(find.text('Neha Sharma'), findsOneWidget);
      expect(find.text('ID: SUP-001'), findsOneWidget);
      expect(find.text('NS'), findsOneWidget);
      expect(find.text('ICU'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      expect(find.text('Pending Supervisor'), findsNothing);
      expect(find.text('ID: SUP-002'), findsNothing);
      expect(find.text('Assigned'), findsNothing);
      expect(find.text('All'), findsNothing);
      expect(find.text('Active'), findsNothing);
    },
  );

  testWidgets('Shows empty state when no assigned supervisors exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    expect(find.text('No supervisors found'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('Back button returns to the previous screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupervisorManagementScreen(
                      adminUser: testAdmin,
                      firestoreService: FirestoreService(),
                    ),
                  ),
                );
              },
              child: const Text('Open Supervisor Management'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Supervisor Management'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('supervisorManagementBackButton')));
    await tester.pumpAndSettle();

    expect(find.text('Open Supervisor Management'), findsOneWidget);
    expect(find.text('Supervisor Management'), findsNothing);
  });
}
