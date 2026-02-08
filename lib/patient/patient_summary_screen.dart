import 'package:flutter/material.dart';
import '../common/ui_shell.dart';
import '../demo/demo_data.dart';

class PatientSummaryScreen extends StatelessWidget {
  const PatientSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "AI Summary (Demo)",
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(DemoData.aiSummarySample(), style: const TextStyle(height: 1.4)),
        ),
      ),
    );
  }
}
