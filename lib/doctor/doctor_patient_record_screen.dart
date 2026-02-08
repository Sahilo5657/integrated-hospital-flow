import 'package:flutter/material.dart';
import '../common/ui_shell.dart';
import '../demo/demo_data.dart';

class DoctorPatientRecordScreen extends StatelessWidget {
  const DoctorPatientRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Patient Record (Demo)",
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Patient: Ali (P-1099)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text("Age: 27 • Gender: Male • Phone: 03xx-xxxxxxx"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Clinical Notes (Demo)", style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text("Patient reports headache for 2 days. No fever. Vitals stable. Advised rest and hydration."),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(DemoData.aiSummarySample(), style: const TextStyle(height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
