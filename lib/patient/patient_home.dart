import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import '../auth/login_screen.dart';
import '../services/eta_service.dart';
import '../wall/wall_mounted_screen.dart';
import 'patient_queue_screen.dart';
import 'patient_summary_screen.dart';

class PatientHome extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  const PatientHome({super.key, this.auth, this.firestore});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _DoctorOption {
  final String uid;
  final String name;
  _DoctorOption({required this.uid, required this.name});
}

class _PatientHomeState extends State<PatientHome> {
  String _patientName = "";
  bool _isLoadingProfile = true;
  double _avgMins = 15.0;

  List<_DoctorOption> _doctors = [];
  String? _selectedDoctorId;
  bool _loadingDoctors = true;

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadPatientProfile();
    _loadDoctors();
    EtaService(firestore: widget.firestore)
        .getEstimatedMinutesPerPatient()
        .then((v) { if (mounted) setState(() => _avgMins = v); });
  }

  Future<void> _loadPatientProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _db.collection('users').doc(user.uid).get();
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
        _patientName = _auth.currentUser?.displayName ?? "Patient";
        _isLoadingProfile = false;
      });
    }
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
          if (list.length == 1) _selectedDoctorId = list.first.uid;
          _loadingDoctors = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDoctors = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          // ── Doctor picker ──────────────────────────────────────────────
          _loadingDoctors
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _doctors.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "No doctors found. Please contact the hospital.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _selectedDoctorId,
                      decoration: const InputDecoration(
                        labelText: "Select Doctor",
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _doctors
                          .map((d) => DropdownMenuItem(
                                value: d.uid,
                                child: Text("Dr. ${d.name}"),
                              ))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedDoctorId = val),
                      hint: const Text("Choose your doctor"),
                    ),
          const SizedBox(height: 16),

          // ── Live Queue Status ──────────────────────────────────────────
          if (_selectedDoctorId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  const Icon(Icons.person_search,
                      size: 64, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  Text(
                    "Hello, $_patientName!",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Select a doctor above to see your queue status.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('queues')
                  .where('doctorId', isEqualTo: _selectedDoctorId)
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

                final allDocs = snapshot.data?.docs ?? [];

                final myActiveDocs = allDocs.where((doc) {
                  final status = (doc.get('status') ?? '') as String;
                  final name = (doc.get('patientName') ?? '') as String;
                  return (status == 'waiting' || status == 'serving') &&
                      name == _patientName;
                }).toList();

                if (myActiveDocs.isEmpty) {
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
                    myActiveDocs.first.data() as Map<String, dynamic>;
                final int tokenNo = ticket['tokenNo'] ?? 0;
                final String queueStatus = ticket['queueStatus'] ?? 'Waiting';
                final bool isServing = queueStatus.toLowerCase() == 'serving';

                int position = 0;
                if (!isServing) {
                  final waitingDocs = allDocs
                      .where((d) => (d.get('status') ?? '') == 'waiting')
                      .toList();
                  waitingDocs.sort((a, b) =>
                      (a.get('tokenNo') as int? ?? 0)
                          .compareTo(b.get('tokenNo') as int? ?? 0));
                  final idx = waitingDocs.indexWhere(
                      (d) => (d.get('patientName') ?? '') == _patientName);
                  position = idx >= 0 ? idx + 1 : 0;
                }

                final etaMins =
                    position > 0 ? (position * _avgMins).round() : 0;

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
                            if (!isServing && position > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.format_list_numbered,
                                      color: Colors.blue.shade700, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Position in line: #$position",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule,
                                      color: Colors.grey.shade600, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Est. wait: ~$etaMins min",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isServing
                                      ? Icons.door_sliding
                                      : Icons.hourglass_top,
                                  color:
                                      isServing ? Colors.green : Colors.blue,
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
                                    builder: (_) => PatientQueueScreen(
                                      doctorId: _selectedDoctorId!,
                                    ),
                                  ),
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

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WallMountedScreen()),
              ),
              icon: const Icon(Icons.tv),
              label: const Text("View Live Queue Board"),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // ── Visit History ──────────────────────────────────────────────
          Row(
            children: [
              const Text(
                "My Visit History",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_selectedDoctorId != null)
                TextButton.icon(
                  onPressed: () => setState(() => _selectedDoctorId = null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text("Show All"),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                      visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _selectedDoctorId == null
                ? "All past consultations and AI-generated summaries."
                : "Filtered by selected doctor — tap 'Show All' to see everything.",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('encounters')
                .where('patientName', isEqualTo: _patientName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data?.docs ?? [];

              // Filter in-memory by selected doctor (avoids composite index)
              final docs = _selectedDoctorId == null
                  ? allDocs
                  : allDocs
                      .where((d) =>
                          (d.data() as Map<String, dynamic>)['doctorId'] ==
                          _selectedDoctorId)
                      .toList();

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      _selectedDoctorId == null
                          ? "No past visits found."
                          : "No visits found for this doctor.",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final sorted = [...docs]..sort((a, b) {
                  final ta = (a.data() as Map)['timestamp'];
                  final tb = (b.data() as Map)['timestamp'];
                  if (ta is Timestamp && tb is Timestamp) {
                    return tb.millisecondsSinceEpoch
                        .compareTo(ta.millisecondsSinceEpoch);
                  }
                  return 0;
                });

              // Resolve doctor name for subtitle when showing all doctors
              final Map<String, String> doctorNameCache = {
                for (final d in _doctors) d.uid: d.name,
              };

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
                  final docId = data['doctorId'] as String?;
                  final docName = docId != null
                      ? doctorNameCache[docId]
                      : null;
                  final subtitle = docName != null
                      ? "$dateStr · Dr. $docName"
                      : dateStr;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Colors.blueGrey.withValues(alpha: 0.1),
                        child: const Icon(Icons.medical_services,
                            color: Colors.blueGrey),
                      ),
                      title: Text(
                        notes.isNotEmpty ? notes : "No notes recorded",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(subtitle),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.grey),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientSummaryScreen(
                            encounterId: doc.id,
                            clinicalNotes: notes,
                            cachedSummary: aiSummary,
                          ),
                        ),
                      ),
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
