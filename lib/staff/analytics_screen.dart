import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  String _formatHour(int hour) {
    if (hour == 0) return "12:00 AM";
    if (hour < 12) return "$hour:00 AM";
    if (hour == 12) return "12:00 PM";
    return "${hour - 12}:00 PM";
  }

  String _weekdayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Clinic Analytics Reports",
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('queues')
            .where('doctorId', isEqualTo: 'sahilo5657@gmail.com')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "No data yet. Patients will appear here once they check in.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Status counts — use actual statuses from the app
          int totalDone = 0;
          int totalSkipped = 0;
          int totalWaiting = 0;
          int totalServing = 0;

          // For peak hour and busiest day
          final Map<int, int> hourCount = {};
          final Map<int, int> dayCount = {};

          // For avg wait time
          int totalEta = 0;
          int etaCount = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] as String? ?? '').toLowerCase();

            if (status == 'done') totalDone++;
            if (status == 'skipped') totalSkipped++;
            if (status == 'waiting') totalWaiting++;
            if (status == 'serving') totalServing++;

            final ts = data['timestamp'];
            if (ts is Timestamp) {
              final dt = ts.toDate();
              hourCount[dt.hour] = (hourCount[dt.hour] ?? 0) + 1;
              dayCount[dt.weekday] = (dayCount[dt.weekday] ?? 0) + 1;
            }

            final eta = data['etaMins'];
            if (eta is int && eta > 0) {
              totalEta += eta;
              etaCount++;
            }
          }

          // Compute peak hour
          String peakHourStr = "N/A";
          if (hourCount.isNotEmpty) {
            final peakHour = hourCount.entries
                .reduce((a, b) => a.value >= b.value ? a : b)
                .key;
            peakHourStr = _formatHour(peakHour);
          }

          // Compute busiest day
          String busiestDayStr = "N/A";
          if (dayCount.isNotEmpty) {
            final busiestDay = dayCount.entries
                .reduce((a, b) => a.value >= b.value ? a : b)
                .key;
            busiestDayStr = _weekdayName(busiestDay);
          }

          // Avg wait time
          final avgWaitStr = etaCount > 0
              ? "${(totalEta / etaCount).round()} mins"
              : "N/A";

          // No-show rate (skipped vs done+skipped)
          final totalProcessed = totalDone + totalSkipped;
          final noShowRate = totalProcessed > 0
              ? (totalSkipped / totalProcessed) * 100
              : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text(
                "Operational Insights Dashboard",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const SizedBox(height: 4),
              Text(
                "Live data from ${docs.length} queue entries",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildAnalyticsCard(
                    title: "Peak Rush Hour",
                    value: peakHourStr,
                    icon: Icons.access_time_filled,
                    color: Colors.orange.shade700,
                  ),
                  _buildAnalyticsCard(
                    title: "Busiest Day",
                    value: busiestDayStr,
                    icon: Icons.calendar_month,
                    color: Colors.red.shade700,
                  ),
                  _buildAnalyticsCard(
                    title: "Avg. Wait Time",
                    value: avgWaitStr,
                    icon: Icons.hourglass_bottom,
                    color: Colors.blue.shade700,
                  ),
                  _buildAnalyticsCard(
                    title: "No-Show Rate",
                    value: "${noShowRate.toStringAsFixed(1)}%",
                    icon: Icons.person_off,
                    color: Colors.purple.shade700,
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              const Text(
                "Volume Distribution Overview",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text("Consultations Completed"),
                trailing: Text("$totalDone", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.timelapse, color: Colors.blue),
                title: const Text("Currently Being Served"),
                trailing: Text("$totalServing", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.pending, color: Colors.amber),
                title: const Text("Waiting in Queue"),
                trailing: Text("$totalWaiting", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text("Skipped / No-Show"),
                trailing: Text("$totalSkipped", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
