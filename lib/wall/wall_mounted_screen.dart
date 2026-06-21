import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_screen.dart';
import '../models/queue_models.dart';
import '../services/eta_service.dart';

class WallMountedScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  const WallMountedScreen({super.key, this.firestore});

  @override
  State<WallMountedScreen> createState() => _WallMountedScreenState();
}

class _DoctorOption {
  final String uid;
  final String name;
  _DoctorOption({required this.uid, required this.name});
}

class _WallMountedScreenState extends State<WallMountedScreen> {
  late Future<double> _etaFuture;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  String? _doctorId;
  List<_DoctorOption> _doctors = [];
  bool _loadingDoctors = true;

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _etaFuture = EtaService(firestore: widget.firestore).getEstimatedMinutesPerPatient();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .get();
      final list = snap.docs
          .map((d) => _DoctorOption(
                uid: d.id,
                name: (d.data()['name'] as String? ?? '').trim(),
              ))
          .where((d) => d.name.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _doctors = list;
          if (list.length == 1) _doctorId = list.first.uid;
          _loadingDoctors = false;
        });
        if (_doctors.isNotEmpty && _doctorId == null) {
          _showDoctorPicker();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDoctors = false);
    }
  }

  void _showDoctorPicker() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? picked = _doctorId;
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            title: const Text("Select Doctor"),
            content: DropdownButtonFormField<String>(
              value: picked,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
              items: _doctors
                  .map((d) => DropdownMenuItem(
                        value: d.uid,
                        child: Text("Dr. ${d.name}"),
                      ))
                  .toList(),
              onChanged: (val) => setDlg(() => picked = val),
              hint: const Text("Choose a doctor"),
            ),
            actions: [
              TextButton(
                onPressed: picked == null
                    ? null
                    : () {
                        setState(() => _doctorId = picked);
                        Navigator.pop(ctx);
                      },
                child: const Text("Confirm"),
              ),
            ],
          ),
        );
      },
    );
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
          // Change doctor
          IconButton(
            onPressed: _showDoctorPicker,
            icon: const Icon(Icons.swap_horiz, color: Color(0xFF58A6FF), size: 20),
            tooltip: 'Change Doctor',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
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
        child: _loadingDoctors
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
            : _doctorId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_hospital,
                            size: 64, color: Color(0xFF58A6FF)),
                        const SizedBox(height: 16),
                        const Text(
                          'Select a doctor to display the queue',
                          style: TextStyle(
                              fontSize: 20, color: Color(0xFFE6EDF3)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showDoctorPicker,
                          icon: const Icon(Icons.local_hospital_outlined),
                          label: const Text('Select Doctor'),
                        ),
                      ],
                    ),
                  )
                : FutureBuilder<double>(
          future: _etaFuture,
          builder: (context, etaSnapshot) {
            final estMins = (etaSnapshot.data ?? 15.0).round();
            final etaReady =
                etaSnapshot.connectionState == ConnectionState.done;

            return StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('queues')
                  .where('doctorId', isEqualTo: _doctorId)
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
