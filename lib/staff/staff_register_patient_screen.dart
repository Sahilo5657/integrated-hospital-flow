import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';

class StaffRegisterPatientScreen extends StatefulWidget {
  const StaffRegisterPatientScreen({super.key});

  @override
  State<StaffRegisterPatientScreen> createState() => _StaffRegisterPatientScreenState();
}

class _StaffRegisterPatientScreenState extends State<StaffRegisterPatientScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnicController = TextEditingController();
  final _nfcController = TextEditingController();
  bool _isLoading = false;

  void _save() async {
    final nfcCardId = _nfcController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final cnic = _cnicController.text.trim();

    // 1. Validation
    if (name.isEmpty || phone.isEmpty || nfcCardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in Name, Phone, and NFC Card ID")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Save flat document directly to 'activated_cards' using nfcCardId as Document ID
      await FirebaseFirestore.instance.collection('activated_cards').doc(nfcCardId).set({
        'nfcCardId': nfcCardId,
        'patientName': name,
        'phone': phone,
        'cnic': cnic, // optional
        'isLinkedToApp': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Patient card activated successfully!")),
        );
        Navigator.of(context).pop(); // Go back after success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _nfcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Activate Patient Card",
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nfcController,
                decoration: const InputDecoration(
                  labelText: "NFC Card ID",
                  prefixIcon: Icon(Icons.nfc),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Patient Full Name")),
              const SizedBox(height: 12),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Phone Number")),
              const SizedBox(height: 12),
              TextField(controller: _cnicController, decoration: const InputDecoration(labelText: "CNIC (Optional)")),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bolt),
                  label: Text(_isLoading ? "Activating..." : "Activate Card"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
