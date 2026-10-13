import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../models/ward_model.dart';

class SupervisorAssignTaskScreen extends StatelessWidget {
  final UserModel? selectedWorker;
  final WardModel? ward;

  const SupervisorAssignTaskScreen({
    super.key,
    this.selectedWorker,
    this.ward,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Assign Task',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Assign Task',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
