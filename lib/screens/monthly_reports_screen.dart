import 'package:flutter/material.dart';

import '../models/task_assignment_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../services/firestore_service.dart';

class MonthlyReportsScreen extends StatelessWidget {
  final FirestoreService? firestoreService;
  final UserModel? adminUser;

  const MonthlyReportsScreen({
    super.key,
    this.firestoreService,
    this.adminUser,
  });

  @override
  Widget build(BuildContext context) {
    return _MonthlyReportsView(
      firestoreService: firestoreService ?? FirestoreService(),
      adminUser: adminUser,
    );
  }
}

class _MonthlyReportsView extends StatefulWidget {
  final FirestoreService firestoreService;
  final UserModel? adminUser;

  const _MonthlyReportsView({
    required this.firestoreService,
    required this.adminUser,
  });

  @override
  State<_MonthlyReportsView> createState() => _MonthlyReportsViewState();
}

class _MonthlyReportsViewState extends State<_MonthlyReportsView> {
  late DateTime _selectedMonth;

  String get _adminInitials {
    final name = widget.adminUser?.name.trim() ?? '';
    if (name.isEmpty) return 'A';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Monthly Ward Reports',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('monthlyReportsNotificationButton'),
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0F172A),
              child: Text(
                _adminInitials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<WardModel>>(
        stream: widget.firestoreService.streamWards(),
        builder: (context, wardsSnapshot) {
          if (wardsSnapshot.hasError) {
            return _MessageState(message: 'Unable to load ward reports.');
          }
          if (!wardsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<TaskModel>>(
            stream: widget.firestoreService.streamTasksByWard(''),
            builder: (context, tasksSnapshot) {
              if (tasksSnapshot.hasError) {
                return _MessageState(message: 'Unable to load task reports.');
              }
              if (!tasksSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<TaskAssignmentModel>>(
                stream: widget.firestoreService.streamAssignmentsByWard(''),
                builder: (context, assignmentsSnapshot) {
                  if (assignmentsSnapshot.hasError) {
                    return _MessageState(
                      message: 'Unable to load assignment reports.',
                    );
                  }
                  if (!assignmentsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final report = MonthlyReportData.create(
                    month: _selectedMonth,
                    wards: wardsSnapshot.data!,
                    tasks: tasksSnapshot.data!,
                    assignments: assignmentsSnapshot.data!,
                  );
                  return _ReportContent(
                    report: report,
                    selectedMonth: _selectedMonth,
                    onMonthChanged: (month) {
                      setState(() => _selectedMonth = month);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  final MonthlyReportData report;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const _ReportContent({
    required this.report,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const Text(
          'REPORTING PERIOD',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        _MonthSelector(
          selectedMonth: selectedMonth,
          availableMonths: report.availableMonths,
          onChanged: onMonthChanged,
        ),
        const SizedBox(height: 16),
        _SummaryCard(summary: report.summary),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Text(
              'Ward comparison',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Higher completion first',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (report.wards.isEmpty)
          const _MessageState(message: 'No ward activity for this month.')
        else
          ...report.wards.map(
            (ward) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WardReportCard(report: ward),
            ),
          ),
      ],
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final List<DateTime> availableMonths;
  final ValueChanged<DateTime> onChanged;

  const _MonthSelector({
    required this.selectedMonth,
    required this.availableMonths,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final months = {
      ...availableMonths.map((month) => DateTime(month.year, month.month)),
      DateTime(selectedMonth.year, selectedMonth.month),
    }.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: DateTime(selectedMonth.year, selectedMonth.month),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: months
              .map(
                (month) => DropdownMenuItem(
                  value: month,
                  child: Text(
                    _formatMonth(month),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (month) {
            if (month != null) onChanged(month);
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ReportMetrics summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All wards at a glance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${summary.wardCount} wards',
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryMetric(
                label: 'TOTAL TASKS',
                value: summary.assigned.toString(),
              ),
              _SummaryMetric(
                label: 'VERIFIED',
                value: '${summary.completionPercent}%',
              ),
              _SummaryMetric(
                label: 'PENDING',
                value: summary.pending.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WardReportCard extends StatelessWidget {
  final WardReportData report;

  const _WardReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WARD REPORT',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      report.name,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${report.metrics.completionPercent}%',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'completion',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: report.metrics.completionRatio,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _CardMetric(label: 'TASKS', value: report.metrics.assigned),
              _CardMetric(label: 'VERIFIED', value: report.metrics.verified),
              _CardMetric(label: 'PENDING', value: report.metrics.pending),
              _CardMetric(
                label: 'NOT COMPLETED',
                value: report.metrics.notCompleted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  final String label;
  final int value;

  const _CardMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;

  const _MessageState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      ),
    );
  }
}

class ReportMetrics {
  final int assigned;
  final int verified;
  final int pending;
  final int notCompleted;
  final int wardCount;

  const ReportMetrics({
    required this.assigned,
    required this.verified,
    required this.pending,
    required this.notCompleted,
    this.wardCount = 0,
  });

  int get completionPercent =>
      assigned == 0 ? 0 : ((verified / assigned) * 100).round();
  double get completionRatio => assigned == 0 ? 0 : verified / assigned;
}

class WardReportData {
  final String name;
  final ReportMetrics metrics;

  const WardReportData({required this.name, required this.metrics});
}

class MonthlyReportData {
  final ReportMetrics summary;
  final List<WardReportData> wards;
  final List<DateTime> availableMonths;

  const MonthlyReportData({
    required this.summary,
    required this.wards,
    required this.availableMonths,
  });

  factory MonthlyReportData.create({
    required DateTime month,
    required List<WardModel> wards,
    required List<TaskModel> tasks,
    required List<TaskAssignmentModel> assignments,
  }) {
    final selectedTasks = tasks.where(
      (task) =>
          task.createdAt.year == month.year &&
          task.createdAt.month == month.month,
    );
    final assignmentById = {
      for (final assignment in assignments) assignment.assignmentId: assignment,
    };
    final assignmentsByTask = <String, List<TaskAssignmentModel>>{};
    for (final assignment in assignments) {
      assignmentsByTask
          .putIfAbsent(assignment.taskId, () => [])
          .add(assignment);
    }
    final reportByWard = <String, ReportMetrics>{};

    for (final task in selectedTasks) {
      final taskAssignments = assignmentsByTask[task.taskId] ?? [];
      final currentAssignment = task.currentAssignmentId != null
          ? assignmentById[task.currentAssignmentId!]
          : _latestAssignment(taskAssignments);
      final current =
          reportByWard[task.wardId] ??
          const ReportMetrics(
            assigned: 0,
            verified: 0,
            pending: 0,
            notCompleted: 0,
          );
      final status = currentAssignment?.status;
      reportByWard[task.wardId] = ReportMetrics(
        assigned: current.assigned + 1,
        verified:
            current.verified +
            (status == AssignmentStatus.verified ||
                    status == AssignmentStatus.autoVerified
                ? 1
                : 0),
        pending:
            current.pending +
            (status == AssignmentStatus.verified ||
                    status == AssignmentStatus.autoVerified ||
                    status == AssignmentStatus.notCompleted
                ? 0
                : 1),
        notCompleted:
            current.notCompleted +
            (status == AssignmentStatus.notCompleted ? 1 : 0),
      );
    }

    final wardReports =
        wards.map((ward) {
          return WardReportData(
            name: ward.name,
            metrics:
                reportByWard[ward.wardId] ??
                const ReportMetrics(
                  assigned: 0,
                  verified: 0,
                  pending: 0,
                  notCompleted: 0,
                ),
          );
        }).toList()..sort(
          (a, b) => b.metrics.completionPercent.compareTo(
            a.metrics.completionPercent,
          ),
        );

    final total = wardReports.fold(
      const ReportMetrics(
        assigned: 0,
        verified: 0,
        pending: 0,
        notCompleted: 0,
      ),
      (value, ward) => ReportMetrics(
        assigned: value.assigned + ward.metrics.assigned,
        verified: value.verified + ward.metrics.verified,
        pending: value.pending + ward.metrics.pending,
        notCompleted: value.notCompleted + ward.metrics.notCompleted,
      ),
    );

    final availableMonths = tasks
        .map((task) => DateTime(task.createdAt.year, task.createdAt.month))
        .toSet()
        .toList();
    return MonthlyReportData(
      summary: ReportMetrics(
        assigned: total.assigned,
        verified: total.verified,
        pending: total.pending,
        notCompleted: total.notCompleted,
        wardCount: wards.length,
      ),
      wards: wardReports,
      availableMonths: availableMonths,
    );
  }
}

TaskAssignmentModel? _latestAssignment(List<TaskAssignmentModel> assignments) {
  if (assignments.isEmpty) return null;
  final sorted = List<TaskAssignmentModel>.from(assignments)
    ..sort((a, b) {
      final numberComparison = b.assignmentNumber.compareTo(a.assignmentNumber);
      return numberComparison != 0
          ? numberComparison
          : b.assignedAt.compareTo(a.assignedAt);
    });
  return sorted.first;
}

String _formatMonth(DateTime month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[month.month - 1]} ${month.year}';
}
