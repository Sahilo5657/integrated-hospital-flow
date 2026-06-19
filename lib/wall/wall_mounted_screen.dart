import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_screen.dart';
import '../models/queue_models.dart';
import '../services/eta_service.dart';

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
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _time() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _date() {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${_now.day} ${months[_now.month]} ${_now.year}';
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: Color(0xFF58A6FF), size: 24),
          const SizedBox(width: 8),
          // Flexible lets the title yield space to the right-side elements
          // instead of pushing them off screen.
          Flexible(
            child: Text(
              'Hospital Patient Flow',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE6EDF3),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Live indicator
          const Icon(Icons.circle, size: 8, color: Color(0xFF3FB950)),
          const SizedBox(width: 4),
          const Text('Live',
              style: TextStyle(fontSize: 12, color: Color(0xFF3FB950))),
          const SizedBox(width: 12),
          // Clock
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _time(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE6EDF3),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(_date(),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF8B949E))),
            ],
          ),
          // Logout
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Color(0xFF8B949E), size: 20),
            tooltip: 'Logout',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Now Serving ─────────────────────────────────────────────────────────────
  Widget _buildNowServing(QueueItem? nowServing) {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF3FB950),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'NOW SERVING',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3FB950),
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Patient display
          Expanded(
            child: nowServing == null
                ? const Center(
                    child: Text(
                      '— No active patient —',
                      style: TextStyle(
                        fontSize: 28,
                        color: Color(0xFF484F58),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3A2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF3FB950), width: 2),
                        ),
                        child: Text(
                          '#${nowServing.tokenNo}',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3FB950),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        child: Text(
                          nowServing.patientName,
                          style: const TextStyle(
                            fontSize: 42,
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

  // ── Waiting List ─────────────────────────────────────────────────────────────
  Widget _buildWaiting(
      List<QueueItem> waiting, int estMins, bool etaReady) {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label + count badge
          Row(
            children: [
              const Text(
                'PATIENTS WAITING',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B949E),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 10),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF58A6FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Queue list
          Expanded(
            child: waiting.isEmpty
                ? const Center(
                    child: Text(
                      'Queue is empty',
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF484F58),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: waiting.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: Color(0xFF21262D),
                      height: 1,
                    ),
                    itemBuilder: (context, i) {
                      final patient = waiting[i];
                      final etaLabel = etaReady
                          ? '~${(i + 1) * estMins} min'
                          : '...';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            // Position number
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF8B949E),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Token chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C2128),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF30363D), width: 1),
                              ),
                              child: Text(
                                '#${patient.tokenNo}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF58A6FF),
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Name
                            Expanded(
                              child: Text(
                                patient.patientName,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE6EDF3),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // ETA badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C2128),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 14,
                                      color: Color(0xFFF0883E)),
                                  const SizedBox(width: 4),
                                  Text(
                                    etaLabel,
                                    style: const TextStyle(
                                      fontSize: 15,
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

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: FutureBuilder<double>(
          future: _etaFuture,
          builder: (context, etaSnapshot) {
            final estMins = (etaSnapshot.data ?? 15.0).round();
            final etaReady =
                etaSnapshot.connectionState == ConnectionState.done;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('queues')
                  .where('doctorId', isEqualTo: 'sahilo5657@gmail.com')
                  .snapshots(),
              builder: (context, queueSnapshot) {
                final allDocs = queueSnapshot.data?.docs ?? [];

                final activeDocs = allDocs.where((d) {
                  final s = (d['status'] ?? '') as String;
                  return s == 'waiting' || s == 'serving';
                }).toList()
                  ..sort((a, b) => (a['tokenNo'] as int? ?? 0)
                      .compareTo(b['tokenNo'] as int? ?? 0));

                final queue = activeDocs
                    .map((d) => QueueItem.fromFirestore(d))
                    .toList();
                final nowServing = queue
                    .where((q) => q.status == QueueStatus.serving)
                    .firstOrNull;
                final waiting = queue
                    .where((q) => q.status == QueueStatus.waiting)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    Expanded(
                      flex: 2,
                      child: _buildNowServing(nowServing),
                    ),
                    const Divider(
                        color: Color(0xFF30363D), thickness: 1, height: 1),
                    Expanded(
                      flex: 3,
                      child: _buildWaiting(waiting, estMins, etaReady),
                    ),
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
