import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/ui_shell.dart';

class DoctorPatientRecordScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DoctorPatientRecordScreen({
    super.key,
    required this.patientId,
    required this.patientName
  });

  @override
  State<DoctorPatientRecordScreen> createState() => _DoctorPatientRecordScreenState();
}

class _DoctorPatientRecordScreenState extends State<DoctorPatientRecordScreen> {
  final _notesController = TextEditingController();
  bool _isLoading = false;

  void _saveEncounter() async {
    if (_notesController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('encounters').add({
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'doctorId': user?.email ?? 'sahilo5657@gmail.com',
        'rawNotes': _notesController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _notesController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notes saved successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Patient Record: ${widget.patientName}",
      child: Column(
        children: [
          // 1. Input for new notes
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: "Add Clinical Notes"),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _saveEncounter,
                        child: Text(_isLoading ? "Saving..." : "Save Encounter"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          // 2. View History (StreamBuilder)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Query by patientName — works for both linked and NFC-only patients,
              // and avoids needing a composite Firestore index.
              stream: FirebaseFirestore.instance
                  .collection('encounters')
                  .where('patientName', isEqualTo: widget.patientName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                // Sort newest-first in memory
                final docs = [...snapshot.data!.docs]..sort((a, b) {
                    final ta = (a.data() as Map)['timestamp'];
                    final tb = (b.data() as Map)['timestamp'];
                    if (ta is Timestamp && tb is Timestamp) {
                      return tb.millisecondsSinceEpoch.compareTo(ta.millisecondsSinceEpoch);
                    }
                    return 0;
                  });
                if (docs.isEmpty) return const Center(child: Text("No history available."));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final notes = data['rawNotes'] ?? data['clinicalNotes'] ?? '';
                    final ts = data['timestamp'] as Timestamp?;
                    final dateStr = ts != null
                        ? ts.toDate().toString().split('.')[0]
                        : 'Unknown date';
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                        notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text("Date: $dateStr"),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}