import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';

class PatientQueueScreen extends StatelessWidget {
  const PatientQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return UIShell(
      title: "My Queue Status",
      child: currentUser == null
          ? const Center(child: Text("Please log in to view status."))
          : StreamBuilder<QuerySnapshot>(
              // 1. Exactly 'queues' collection
              // 2. Filters by patientId using current user's UID
              stream: FirebaseFirestore.instance
                  .collection('queues')
                  .where('patientId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Filter active items in memory to avoid complex Firestore composite indexes for now
                final activeItems = snapshot.data!.docs
                    .map((d) => QueueItem.fromFirestore(d))
                    .where((q) => q.status != QueueStatus.done)
                    .toList();

                if (activeItems.isEmpty) {
                  return _buildEmptyState();
                }

                // Sorting to find the most recent/active token if there are multiple (unlikely)
                activeItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                final myQueue = activeItems.first;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildStatusCard(context, myQueue),
                      const SizedBox(height: 24),
                      _buildInfoSection(context, myQueue),
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

  Widget _buildInfoSection(BuildContext context, QueueItem item) {
    return Column(
      children: [
        _buildInfoRow(Icons.timer_outlined, "Estimated Wait", "${item.etaMins} mins"),
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