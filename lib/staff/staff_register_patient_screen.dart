import 'package:flutter/material.dart';
import '../common/ui_shell.dart';

class StaffRegisterPatientScreen extends StatefulWidget {
  const StaffRegisterPatientScreen({super.key});

  @override
  State<StaffRegisterPatientScreen> createState() => _StaffRegisterPatientScreenState();
}

class _StaffRegisterPatientScreenState extends State<StaffRegisterPatientScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final cnic = TextEditingController();
  final nfc = TextEditingController(text: "NFC-XXXX-XXXX");

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved (Demo). Final build will write to Firestore.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Register Patient (Demo)",
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: "Patient Full Name")),
              const SizedBox(height: 12),
              TextField(controller: phone, decoration: const InputDecoration(labelText: "Phone Number")),
              const SizedBox(height: 12),
              TextField(controller: cnic, decoration: const InputDecoration(labelText: "CNIC (Optional)")),
              const SizedBox(height: 12),
              TextField(controller: nfc, decoration: const InputDecoration(labelText: "NFC Card Code (Demo)")),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text("Save Patient"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
