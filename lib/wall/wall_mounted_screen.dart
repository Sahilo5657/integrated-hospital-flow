import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/queue_models.dart';
import '../services/eta_service.dart';

/// Full-screen wall-display intended for a lobby monitor or mounted tablet.
/// Accessible by logging in as wallmounted@gmail.com.
///
/// ETA algorithm: Exponential Moving Average (EMA, α = 0.35) over historical
/// inter-encounter durations — adapts to the doctor's current pace in real
/// time rather than using a fixed constant.
class WallMountedScreen extends StatefulWidget {
  const WallMountedScreen({super.key});

  @override
  State<WallMountedScreen> createState() => _WallMountedScreenState();
}

class _WallMountedScreenState extends State<WallMountedScreen> {
  late Future<double> _etaFuture;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _etaFuture = EtaService().getEstimatedMinutesPerPatient();
    // Refresh the clock display every minute
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: FutureBuilder<double>(
          future: _etaFuture,
          builder: (context, etaSnapshot) {
            final estMins = (etaSnapshot.data ?? 15.0).round();

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('queues')
                  .where('doctorId', isEqualTo: 'sahilo5657@gmail.com')
                  .snapshots(),
              builder: (context, queueSnapshot) {
                final allDocs = queueSnapshot.data?.docs ?? [];

                // Filter and sort in-memory — no composite index needed
                final activeDocs = allDocs.where((d) {
                  final s = (d['status'] ?? '') as String;
                  return s == 'waiting' || s == 'serving';
                }).toList()
                  ..sort((a, b) => (a['tokenNo'] as int? ?? 0)
                      .compareTo(b['tokenNo'] as int? ?? 0));

                final queue =
                    activeDocs.map((d) => QueueItem.fromFirestore(d)).toList();
                final nowServing = queue
                    .where((q) => q.status == QueueStatus.serving)
                    .firstOrNull;
                final waiting =
                    queue.where((q) => q.status == QueueStatus.waiting).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header bar ──────────────────────────────────────
                    _Header(
                      now: _now,
                      formatTime: _formatTime,
                      formatDate: _formatDate,
                    ),

                    // ── Now Serving ──────────────────────────────────────
                    Expanded(
                      flex: 2,
                      child: _NowServingPanel(nowServing: nowServing),
                    ),

                    const Divider(
                        color: Color(0xFF30363D), thickness: 1, height: 1),

                    // ── Waiting Queue ────────────────────────────────────
                    Expanded(
                      flex: 3,
                      child: _WaitingPanel(
                        waiting: waiting,
                        estMinsPerPatient: estMins,
                        etaReady: etaSnapshot.connectionState == ConnectionState.done,
                      ),
                    ),

                    // ── Footer ───────────────────────────────────────────
                    _Footer(estMins: estMins, colorScheme: colorScheme),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets kept small for readability
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.now,
    required this.formatTime,
    required this.formatDate,
  });

  final DateTime now;
  final String Function(DateTime) formatTime;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: Color(0xFF58A6FF), size: 28),
          const SizedBox(width: 12),
          const Text(
            'Hospital Patient Flow',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE6EDF3),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatTime(now),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE6EDF3),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                formatDate(now),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8B949E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NowServingPanel extends StatelessWidget {
  const _NowServingPanel({required this.nowServing});
  final QueueItem? nowServing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF3FB950),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'NOW SERVING',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3FB950),
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (nowServing == null)
            const Expanded(
              child: Center(
                child: Text(
                  '— No active patient —',
                  style: TextStyle(
                    fontSize: 32,
                    color: Color(0xFF484F58),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF3FB950), width: 2),
                    ),
                    child: Text(
                      '#${nowServing!.tokenNo}',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3FB950),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Text(
                      nowServing!.patientName,
                      style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE6EDF3),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({
    required this.waiting,
    required this.estMinsPerPatient,
    required this.etaReady,
  });

  final List<QueueItem> waiting;
  final int estMinsPerPatient;
  final bool etaReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'PATIENTS WAITING',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B949E),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2128),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${waiting.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF58A6FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (waiting.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Queue is empty',
                  style: TextStyle(
                    fontSize: 22,
                    color: Color(0xFF484F58),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: waiting.length,
                separatorBuilder: (_, _) => const Divider(
                  color: Color(0xFF21262D),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final patient = waiting[index];
                  final etaMins =
                      etaReady ? (index + 1) * estMinsPerPatient : null;
                  final etaLabel = etaMins != null
                      ? '~$etaMins min'
                      : '...';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        // Position badge
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B949E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Token chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2128),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF30363D), width: 1),
                          ),
                          child: Text(
                            '#${patient.tokenNo}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF58A6FF),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        // Name
                        Expanded(
                          child: Text(
                            patient.patientName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE6EDF3),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // ETA
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2128),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule,
                                  size: 15, color: Color(0xFFF0883E)),
                              const SizedBox(width: 5),
                              Text(
                                etaLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF0883E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer(
      {required this.estMins, required this.colorScheme});

  final int estMins;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF8B949E)),
          const SizedBox(width: 6),
          Text(
            'ETA model: Exponential Moving Average (α = 0.35) on historical records  •  ~$estMins min/patient',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8B949E),
            ),
          ),
          const Spacer(),
          const Icon(Icons.circle, size: 8, color: Color(0xFF3FB950)),
          const SizedBox(width: 5),
          const Text(
            'Live',
            style: TextStyle(fontSize: 12, color: Color(0xFF3FB950)),
          ),
        ],
      ),
    );
  }
}
