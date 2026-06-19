import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import '../auth/login_screen.dart';
import 'patient_queue_screen.dart';
import 'patient_summary_screen.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  String _patientName = "";
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadPatientProfile();
  }

  Future<void> _loadPatientProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          setState(() {
            _patientName = userDoc.data()?['name'] ?? "";
            _isLoadingProfile = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _patientName = FirebaseAuth.instance.currentUser?.displayName ?? "Patient";
        _isLoadingProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return UIShell(
      title: "Patient Dashboard",
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            }
          },
          tooltip: "Logout",
        ),
      ],
      child: ListView(
        children: [
          // ── Live Queue Status ──
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('queues')
                .where('doctorId', isEqualTo: 'sahilo5657@gmail.com')
                .where('patientName', isEqualTo: _patientName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final activeDocs = snapshot.data?.docs.where((doc) {
                    final status = doc.get('status') ?? '';
                    return status == 'waiting' || status == 'serving';
                  }).toList() ??
                  [];

              if (activeDocs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.nfc, size: 72, color: Colors.blueGrey),
                      const SizedBox(height: 16),
                      Text(
                        "Hello, $_patientName!",
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "You are not in the queue. Tap your NFC card at the front desk to get a token.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final ticket =
                  activeDocs.first.data() as Map<String, dynamic>;
              final int tokenNo = ticket['tokenNo'] ?? 0;
              final String queueStatus =
                  ticket['queueStatus'] ?? 'Waiting';
              final bool isServing =
                  queueStatus.toLowerCase() == 'serving';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, $_patientName",
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text("Your live queue token:"),
                  const SizedBox(height: 16),
                  Card(
                    color: isServing
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            isServing ? "NOW SERVING" : "CURRENT STATUS",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isServing
                                  ? Colors.green.shade800
                                  : Colors.blue.shade800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Token #$tokenNo",
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isServing
                                    ? Icons.door_sliding
                                    : Icons.hourglass_top,
                                color: isServing
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isServing
                                      ? "Please proceed to the Doctor's room now!"
                                      : "Please wait — you will be called shortly.",
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PatientQueueScreen()),
                              ),
                              icon: const Icon(Icons.info_outline),
                              label: const Text("Detailed Queue Status"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),

          // ── Visit History ──
          const Text(
            "My Visit History",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Past consultations and AI-generated summaries.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('encounters')
                .where('patientName', isEqualTo: _patientName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "No past visits found.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              // Sort newest first
              final sorted = [...docs]..sort((a, b) {
                  final ta = (a.data() as Map)['timestamp'];
                  final tb = (b.data() as Map)['timestamp'];
                  if (ta is Timestamp && tb is Timestamp) {
                    return tb.millisecondsSinceEpoch
                        .compareTo(ta.millisecondsSinceEpoch);
                  }
                  return 0;
                });

              return Column(
                children: sorted.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final notes =
                      data['rawNotes'] ?? data['clinicalNotes'] ?? '';
                  final aiSummary = data['aiSummary'] as String?;
                  final ts = data['timestamp'] as Timestamp?;
                  final dateStr = ts != null
                      ? "${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}"
                      : "Unknown date";

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Colors.blueGrey.withOpacity(0.1),
                        child: const Icon(Icons.medical_services,
                            color: Colors.blueGrey),
                      ),
                      title: Text(
                        notes.isNotEmpty ? notes : "No notes recorded",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(dateStr),
                      trailing: notes.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.auto_awesome,
                                  color: Colors.purple),
                              tooltip: "View AI Summary",
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PatientSummaryScreen(
                                    encounterId: doc.id,
                                    clinicalNotes: notes,
                                    cachedSummary: aiSummary,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
