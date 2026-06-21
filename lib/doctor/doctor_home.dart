import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../common/ui_card.dart';
import '../common/ui_section.dart';
import '../common/ui_shell.dart';
import '../models/user_profile.dart';
import '../services/ai_summary_service.dart';
import 'doctor_queue_screen.dart';
import 'doctor_patient_list_screen.dart';
import '../auth/login_screen.dart';
import '../services/doctor_settings_service.dart';

class DoctorHome extends StatefulWidget {
  final FirebaseFirestore? firestore;
  const DoctorHome({super.key, this.firestore});

  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  Future<UserProfile?>? _profileFuture;
  final _clinicalNotesController = TextEditingController();
  bool _isProcessingAI = false;
  String _aiStatus = 'Generating AI summary…';
  DoctorSettings _settings = const DoctorSettings();
  final _limitController = TextEditingController();
  bool _savingSettings = false;

  String get _doctorId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _profileFuture = context.read<AuthService>().getUserProfile(user.uid);
    }
    DoctorSettingsService(doctorId: _doctorId, firestore: widget.firestore)
        .getSettings()
        .then((s) {
      if (mounted) {
        setState(() {
          _settings = s;
          _limitController.text = s.dailyLimit.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _clinicalNotesController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Doctor Dashboard",
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
      child: FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final doctorName = profileSnapshot.data?.name ?? 'Doctor';

          // Single stream — no composite index needed. Filter in-memory below.
          return StreamBuilder<QuerySnapshot>(
            stream: (widget.firestore ?? FirebaseFirestore.instance)
                .collection('queues')
                .where('doctorId', isEqualTo: _doctorId)
                .snapshots(),
            builder: (context, allQueuesSnapshot) {
              final allDocs = allQueuesSnapshot.data?.docs ?? [];

              final servingDocs = allDocs
                  .where((d) => (d['status'] ?? '') == 'serving')
                  .toList();
              final waitingDocs = allDocs
                  .where((d) => (d['status'] ?? '') == 'waiting')
                  .toList();

              final servingDoc =
                  servingDocs.isNotEmpty ? servingDocs.first : null;
              final waitingCount = waitingDocs.length;

              final String activePatientName = servingDoc != null
                  ? servingDoc['patientName']
                  : "No Active Patient";
              final String activePatientId =
                  servingDoc != null ? (servingDoc['patientId'] ?? '') : '';

              return ListView(
                children: [
                  Text(
                    "Welcome, Dr. $doctorName",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                      "Manage active patient checkups and record clinical notes below."),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: UICard(
                          title: "Now Serving",
                          value: servingDoc == null
                              ? "—"
                              : "#${servingDoc['tokenNo']}",
                          icon: Icons.campaign_outlined,
                          subtitle: activePatientName,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: UICard(
                          title: "Waiting",
                          value: "$waitingCount",
                          icon: Icons.people_alt_outlined,
                          subtitle: "Patients in queue",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.edit_note,
                                  color: Colors.blueGrey, size: 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Active Checkup: $activePatientName",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _clinicalNotesController,
                            maxLines: 5,
                            enabled: servingDoc != null && !_isProcessingAI,
                            decoration: InputDecoration(
                              hintText: servingDoc != null
                                  ? "Record symptoms, diagnosis, prescriptions, vitals..."
                                  : "Click 'Call Next' to activate a patient slot before recording notes.",
                              border: const OutlineInputBorder(),
                              focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blueGrey, width: 2)),
                              filled: true,
                              fillColor: servingDoc != null
                                  ? Colors.white
                                  : Colors.grey.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  UISection(
                    title: "Queue & Session Controls",
                    children: [
                      if (_isProcessingAI)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              children: [
                                const CircularProgressIndicator(
                                    color: Colors.blueGrey),
                                const SizedBox(height: 12),
                                Text(_aiStatus,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.blueGrey)),
                                const SizedBox(height: 4),
                                const Text(
                                  'First load may take 1–3 min.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor:
                                        Colors.blueGrey.shade700),
                                onPressed: _isProcessingAI
                                    ? null
                                    : () async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        try {
                                          // Single query — no composite index
                                          final snapshot =
                                              await FirebaseFirestore.instance
                                                  .collection('queues')
                                                  .where('doctorId',
                                                      isEqualTo: _doctorId)
                                                  .get();

                                          final batch = FirebaseFirestore
                                              .instance
                                              .batch();

                                          // Mark all currently serving as done
                                          for (var doc in snapshot.docs) {
                                            if ((doc['status'] ?? '') ==
                                                'serving') {
                                              batch.update(doc.reference, {
                                                'status': 'done',
                                                'queueStatus': 'Done',
                                              });
                                            }
                                          }

                                          // Find next waiting patient by lowest tokenNo
                                          final waitingList = snapshot.docs
                                              .where((d) =>
                                                  (d['status'] ?? '') ==
                                                  'waiting')
                                              .toList();

                                          if (waitingList.isNotEmpty) {
                                            waitingList.sort((a, b) =>
                                                (a['tokenNo'] as int? ?? 0)
                                                    .compareTo(b['tokenNo']
                                                            as int? ??
                                                        0));
                                            batch.update(
                                                waitingList.first.reference,
                                                {
                                                  'status': 'serving',
                                                  'queueStatus': 'Serving',
                                                });
                                            _clinicalNotesController.clear();
                                          } else {
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      "No more patients waiting.")),
                                            );
                                          }

                                          await batch.commit();
                                        } catch (e) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text("Error: $e"),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.skip_next),
                                label: const Text("Call Next"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.green.shade700),
                                onPressed:
                                    (servingDoc == null || _isProcessingAI)
                                        ? null
                                        : () async {
                                            final String enteredNotes =
                                                _clinicalNotesController.text
                                                    .trim();
                                            if (enteredNotes.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      "Please enter clinical notes before completing the visit."),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                              return;
                                            }

                                            setState(() {
                                              _isProcessingAI = true;
                                              _aiStatus = 'Connecting to AI model…';
                                            });

                                            final messenger =
                                                ScaffoldMessenger.of(context);

                                            try {
                                              // 1. Save encounter
                                              final encounterRef =
                                                  FirebaseFirestore.instance
                                                      .collection('encounters')
                                                      .doc();
                                              await encounterRef.set({
                                                'encounterId': encounterRef.id,
                                                'patientId': activePatientId,
                                                'patientName':
                                                    activePatientName,
                                                'doctorId': _doctorId,
                                                'timestamp': FieldValue
                                                    .serverTimestamp(),
                                                'rawNotes': enteredNotes,
                                              });

                                              // 2. Call AI summary
                                              String aiSummary;
                                              try {
                                                aiSummary =
                                                    await AISummaryService()
                                                        .getSummary(
                                                            encounterRef.id,
                                                            enteredNotes,
                                                            onStatus: (msg) {
                                                              if (mounted) setState(() => _aiStatus = msg);
                                                            });
                                              } catch (_) {
                                                aiSummary =
                                                    "Summary generation failed. Please try again from the queue screen.";
                                              }

                                              // 3. Persist AI summary
                                              await encounterRef.update(
                                                  {'aiSummary': aiSummary});

                                              // 4. Mark patient done
                                              await servingDoc.reference
                                                  .update({
                                                'status': 'done',
                                                'queueStatus': 'Done',
                                              });

                                              _clinicalNotesController.clear();

                                              if (mounted) {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        "Visit complete! AI summary saved for $activePatientName."),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content:
                                                        Text("Error: $e"),
                                                    backgroundColor:
                                                        Colors.red,
                                                  ),
                                                );
                                              }
                                            }

                                            if (mounted) {
                                              setState(() =>
                                                  _isProcessingAI = false);
                                            }
                                          },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text("Complete Visit"),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => DoctorQueueScreen(doctorId: _doctorId)),
                          ),
                          icon: const Icon(Icons.list_alt),
                          label: const Text("View Full Queue"),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DoctorPatientListScreen(
                                  doctorId: _doctorId,
                                  firestore: widget.firestore),
                            ),
                          ),
                          icon: const Icon(Icons.history),
                          label: const Text("Patient History"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  UISection(
                    title: "Queue Limits",
                    children: [
                      const Text(
                        "Control how many patients the doctor accepts per day and when appointments stop.",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _limitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Daily patient limit",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people_alt_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                  hour: _settings.endTimeHour,
                                  minute: _settings.endTimeMinute),
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _settings = DoctorSettings(
                                  dailyLimit: int.tryParse(
                                          _limitController.text.trim()) ??
                                      _settings.dailyLimit,
                                  endTimeHour: picked.hour,
                                  endTimeMinute: picked.minute,
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            _settings.endTimeSet
                                ? "Working until: ${_settings.endTimeLabel}"
                                : "Set end time for appointments (optional)",
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal.shade700),
                          onPressed: _savingSettings
                              ? null
                              : () async {
                                  final limit = int.tryParse(
                                          _limitController.text.trim()) ??
                                      0;
                                  if (limit < 1) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Limit must be at least 1.")),
                                    );
                                    return;
                                  }
                                  final newSettings = DoctorSettings(
                                    dailyLimit: limit,
                                    endTimeHour: _settings.endTimeHour,
                                    endTimeMinute: _settings.endTimeMinute,
                                  );
                                  setState(() => _savingSettings = true);
                                  try {
                                    await DoctorSettingsService(
                                            doctorId: _doctorId,
                                            firestore: widget.firestore)
                                        .saveSettings(newSettings);
                                    if (mounted) {
                                      setState(() {
                                        _settings = newSettings;
                                        _savingSettings = false;
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text("Queue limits saved."),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(
                                          () => _savingSettings = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text("Error: $e"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: _savingSettings
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(
                              _savingSettings ? "Saving..." : "Save Limits"),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
