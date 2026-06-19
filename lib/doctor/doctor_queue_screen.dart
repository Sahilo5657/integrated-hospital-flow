import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';
import '../services/ai_summary_service.dart';
import 'doctor_patient_record_screen.dart';

class DoctorQueueScreen extends StatelessWidget {
  const DoctorQueueScreen({super.key});

  void _servePatient(String docId) {
    FirebaseFirestore.instance.collection('queues').doc(docId).update({
      'status': 'serving',
      'queueStatus': 'Serving',
    });
  }

  void _showAISummary(
      BuildContext context, String patientId, String patientName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Query by patientName — more reliable since patientId may be empty for NFC check-ins
      final encounterQuery = await FirebaseFirestore.instance
          .collection('encounters')
          .where('patientName', isEqualTo: patientName)
          .get();

      if (encounterQuery.docs.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("No clinical notes found for this patient.")),
          );
        }
        return;
      }

      // Sort in memory to get the latest encounter
      final sorted = [...encounterQuery.docs]..sort((a, b) {
          final ta = (a.data()['timestamp'] as Timestamp?)
                  ?.millisecondsSinceEpoch ??
              0;
          final tb = (b.data()['timestamp'] as Timestamp?)
                  ?.millisecondsSinceEpoch ??
              0;
          return tb.compareTo(ta);
        });

      final latestEncounter = sorted.first;
      final data = latestEncounter.data();

      // Prefer rawNotes, fall back to clinicalNotes
      final String notes =
          data['rawNotes'] ?? data['clinicalNotes'] ?? '';
      final String encounterId = latestEncounter.id;

      if (notes.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No clinical notes recorded yet.")),
          );
        }
        return;
      }

      // Use cached aiSummary from encounter doc if available; otherwise call API
      final String? cachedSummary = data['aiSummary'] as String?;
      String summary;
      if (cachedSummary != null &&
          cachedSummary.isNotEmpty &&
          !cachedSummary.startsWith("Summary generation failed")) {
        summary = cachedSummary;
      } else {
        summary = await AISummaryService().getSummary(encounterId, notes);
      }

      if (context.mounted) {
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "AI Summary: $patientName",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const Icon(Icons.auto_awesome, color: Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(summary,
                        style: const TextStyle(fontSize: 15, height: 1.6)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Today's Queue",
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('queues')
            .where('doctorId', isEqualTo: 'sahilo5657@gmail.com')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Card(
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          size: 48, color: Colors.blue.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        "Could not load queue",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(snapshot.error.toString(),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];
          final docs = allDocs.where((doc) {
            final status =
                (doc.get('status') as String? ?? '').toLowerCase();
            return status == 'waiting' || status == 'serving';
          }).toList();

          docs.sort((a, b) =>
              (a.get('tokenNo') as int? ?? 0)
                  .compareTo(b.get('tokenNo') as int? ?? 0));

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 80, color: Colors.green.shade200),
                    const SizedBox(height: 24),
                    const Text(
                      "All caught up!",
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "No patients currently waiting or being served.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final q = QueueItem.fromFirestore(docs[i]);

              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(.12),
                        child: Text(
                          "${q.tokenNo}",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      title: Text(q.patientName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text("ETA: ${q.etaMins} min"),
                      trailing: q.status == QueueStatus.waiting
                          ? IconButton(
                              icon: const Icon(Icons.campaign,
                                  color: Colors.blue),
                              onPressed: () => _servePatient(q.id),
                              tooltip: "Call Patient",
                            )
                          : const Chip(
                              label: Text("SERVING"),
                              backgroundColor: Colors.blue,
                              labelStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 8, right: 8, bottom: 8),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _showAISummary(
                                context, q.patientId, q.patientName),
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: const Text("AI Summary"),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.purple),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DoctorPatientRecordScreen(
                                  patientId: q.patientId,
                                  patientName: q.patientName,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text("View Record"),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
