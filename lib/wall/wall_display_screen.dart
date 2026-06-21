import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import '../models/queue_models.dart';
import '../services/eta_service.dart';
import '../services/doctor_settings_service.dart';

class WallDisplayScreen extends StatefulWidget {
  final String doctorId;
  final FirebaseFirestore? firestore;
  const WallDisplayScreen({super.key, required this.doctorId, this.firestore});

  @override
  State<WallDisplayScreen> createState() => _WallDisplayScreenState();
}

class _WallDisplayScreenState extends State<WallDisplayScreen> {
  double _avgMins = 15.0;
  DoctorSettings _settings = const DoctorSettings();

  @override
  void initState() {
    super.initState();
    EtaService(firestore: widget.firestore)
        .getEstimatedMinutesPerPatient()
        .then((v) { if (mounted) setState(() => _avgMins = v); });
    DoctorSettingsService(doctorId: widget.doctorId, firestore: widget.firestore)
        .getSettings()
        .then((s) { if (mounted) setState(() => _settings = s); });
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Wall Display",
      child: StreamBuilder<QuerySnapshot>(
        stream: (widget.firestore ?? FirebaseFirestore.instance)
            .collection('queues')
            .where('doctorId', isEqualTo: widget.doctorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint("WallDisplay Error: ${snapshot.error}");
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Today's total count from the full queue stream (includes done entries)
          final today = DateTime.now();
          int todayCount = 0;
          for (final doc in allDocs) {
            final ts = doc['timestamp'];
            if (ts is Timestamp) {
              final d = ts.toDate();
              if (d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day) {
                todayCount++;
              }
            }
          }

          final docs = allDocs.where((doc) {
            final status = (doc.get('status') as String? ?? '').toLowerCase();
            return status == 'waiting' || status == 'serving';
          }).toList();

          docs.sort((a, b) =>
              (a.get('tokenNo') as int? ?? 0)
                  .compareTo(b.get('tokenNo') as int? ?? 0));

          final queue = docs.map((doc) => QueueItem.fromFirestore(doc)).toList();

          final nowServing =
              queue.where((q) => q.status == QueueStatus.serving).firstOrNull;
          final waiting =
              queue.where((q) => q.status == QueueStatus.waiting).toList();

          final isFull = todayCount >= _settings.dailyLimit;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Now Serving ─────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("NOW SERVING",
                          style: TextStyle(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(
                        nowServing == null
                            ? "—"
                            : "#${nowServing.tokenNo}  •  ${nowServing.patientName}",
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Today's Capacity ─────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isFull ? Colors.red.shade50 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isFull
                          ? Colors.red.shade200
                          : Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFull ? Icons.block : Icons.people_alt_outlined,
                      color: isFull
                          ? Colors.red.shade700
                          : Colors.teal.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today: $todayCount / ${_settings.dailyLimit} patients",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isFull
                                  ? Colors.red.shade800
                                  : Colors.teal.shade800,
                            ),
                          ),
                          if (_settings.endTimeSet)
                            Text(
                              "Appointments until ${_settings.endTimeLabel}",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                        ],
                      ),
                    ),
                    if (isFull)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "FULL",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Next in Line ─────────────────────────────────────────────
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("NEXT IN LINE",
                            style: TextStyle(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        if (waiting.isEmpty)
                          const Text("No upcoming patients.",
                              style: TextStyle(fontSize: 18))
                        else
                          // ETA is cumulative: position × avg consultation time
                          ...waiting
                              .take(5)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                            final i = entry.key;
                            final n = entry.value;
                            // (i + 1) because the currently-serving patient must finish first
                            final etaMins = ((i + 1) * _avgMins).round();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text("#${n.tokenNo}",
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.patientName,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800),
                                        ),
                                        Text(
                                          "Est. Wait: $etaMins min",
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
