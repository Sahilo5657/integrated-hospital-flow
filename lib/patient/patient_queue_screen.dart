import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';
import '../services/eta_service.dart';

class PatientQueueScreen extends StatefulWidget {
  final String doctorId;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  const PatientQueueScreen({super.key, required this.doctorId, this.auth, this.firestore});

  @override
  State<PatientQueueScreen> createState() => _PatientQueueScreenState();
}

class _PatientQueueScreenState extends State<PatientQueueScreen> {
  double _avgMins = 15.0;

  @override
  void initState() {
    super.initState();
    EtaService(firestore: widget.firestore)
        .getEstimatedMinutesPerPatient()
        .then((v) { if (mounted) setState(() => _avgMins = v); });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = (widget.auth ?? FirebaseAuth.instance).currentUser;

    return UIShell(
      title: "My Queue Status",
      child: currentUser == null
          ? const Center(child: Text("Please log in to view status."))
          : StreamBuilder<QuerySnapshot>(
              // Fetch the full active queue so we can compute position
              stream: (widget.firestore ?? FirebaseFirestore.instance)
                  .collection('queues')
                  .where('doctorId', isEqualTo: widget.doctorId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Keep only active (waiting/serving) entries, sorted by token
                final activeDocs = snapshot.data!.docs.where((d) {
                  final status = (d.get('status') as String? ?? '').toLowerCase();
                  return status == 'waiting' || status == 'serving';
                }).toList()
                  ..sort((a, b) => (a.get('tokenNo') as int? ?? 0)
                      .compareTo(b.get('tokenNo') as int? ?? 0));

                // Find this patient's position in the sorted active queue
                final myIndex = activeDocs.indexWhere(
                    (d) => (d.get('patientId') ?? '') == currentUser.uid);

                if (myIndex == -1) return _buildEmptyState();

                final myQueue = QueueItem.fromFirestore(activeDocs[myIndex]);

                // myIndex patients are ahead: each takes ~_avgMins to be served
                final etaMins = myIndex == 0 && myQueue.status == QueueStatus.serving
                    ? 0
                    : (myIndex * _avgMins).round();

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildStatusCard(context, myQueue),
                      const SizedBox(height: 24),
                      _buildInfoSection(context, myQueue, etaMins),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text("You are not currently in any queue.",
              style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, QueueItem item) {
    final color = item.status == QueueStatus.serving ? Colors.green : Colors.blue;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Text("YOUR TOKEN",
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            Text("#${item.tokenNo}",
                style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.status.label.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, QueueItem item, int etaMins) {
    final etaLabel = item.status == QueueStatus.serving
        ? "Now serving"
        : "$etaMins mins";

    return Column(
      children: [
        _buildInfoRow(Icons.timer_outlined, "Estimated Wait", etaLabel),
        const Divider(height: 32),
        _buildInfoRow(Icons.person_outline, "Patient Name", item.patientName),
        const Divider(height: 32),
        _buildInfoRow(Icons.calendar_today_outlined, "Date",
            "${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year}"),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
