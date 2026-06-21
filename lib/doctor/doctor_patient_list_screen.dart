import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import 'doctor_patient_history_screen.dart';

class DoctorPatientListScreen extends StatelessWidget {
  final String doctorId;
  final FirebaseFirestore? firestore;
  const DoctorPatientListScreen(
      {super.key, required this.doctorId, this.firestore});

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return "${d.day}/${d.month}/${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Patient History",
      child: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('encounters')
            .where('doctorId', isEqualTo: doctorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No patient history yet.",
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          // Group encounters by patient name, tracking visit count + last date
          final Map<String, _PatientEntry> map = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['patientName'] as String? ?? '').trim();
            final patientId = data['patientId'] as String? ?? '';
            if (name.isEmpty) continue;

            final ts = data['timestamp'] as Timestamp?;
            final date = ts?.toDate();

            map.putIfAbsent(name, () => _PatientEntry(name: name, patientId: patientId));
            map[name]!.visitCount++;
            if (date != null) {
              final last = map[name]!.lastVisit;
              if (last == null || date.isAfter(last)) {
                map[name]!.lastVisit = date;
              }
            }
          }

          final patients = map.values.toList()
            ..sort((a, b) =>
                (b.lastVisit ?? DateTime(0)).compareTo(a.lastVisit ?? DateTime(0)));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = patients[i];
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    child: Text(
                      p.name[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    "${p.visitCount} visit${p.visitCount == 1 ? '' : 's'}"
                    " · Last: ${_formatDate(p.lastVisit)}",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorPatientHistoryScreen(
                        patientName: p.name,
                        patientId: p.patientId,
                        firestore: firestore,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PatientEntry {
  final String name;
  final String patientId;
  int visitCount = 0;
  DateTime? lastVisit;
  _PatientEntry({required this.name, required this.patientId});
}
