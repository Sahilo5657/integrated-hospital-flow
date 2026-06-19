import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';

class WallDisplayScreen extends StatelessWidget {
  const WallDisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Wall Display",
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('queues')
            .where('doctorId', isEqualTo: 'sahilo5657@gmail.com')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint("WallDisplay Error: ${snapshot.error}");
          }

          final allDocs = snapshot.data?.docs ?? [];
          // Filter in-memory for 'waiting' or 'serving' status (including capitalized)
          final docs = allDocs.where((doc) {
            final status = (doc.get('status') as String? ?? '').toLowerCase();
            return status == 'waiting' || status == 'serving';
          }).toList();
          
          // Sort by token number
          docs.sort((a, b) => (a.get('tokenNo') as int? ?? 0).compareTo(b.get('tokenNo') as int? ?? 0));

          final queue = docs.map((doc) => QueueItem.fromFirestore(doc)).toList();

          final nowServing = queue.where((q) => q.status == QueueStatus.serving).firstOrNull;
          final waiting = queue.where((q) => q.status == QueueStatus.waiting).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Now Serving Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("NOW SERVING", style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(
                        nowServing == null ? "—" : "#${nowServing.tokenNo}  •  ${nowServing.patientName}",
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Next Patients List (With Explicit ETA)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("NEXT IN LINE", style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        if (waiting.isEmpty)
                          const Text("No upcoming patients.", style: TextStyle(fontSize: 18))
                        else
                          ...waiting.take(5).toList().asMap().entries.map((entry) {
                            int index = entry.key;
                            QueueItem n = entry.value;
                            // Explicit ETA calculation: (index + 1) * 10 mins
                            int eta = (index + 1) * 10;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text("#${n.tokenNo}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.patientName,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                        ),
                                        Text(
                                          "Estimated Wait: $eta mins",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
