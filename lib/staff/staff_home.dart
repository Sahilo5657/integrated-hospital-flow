import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import '../wall/wall_display_screen.dart';
import '../auth/login_screen.dart';
import 'analytics_screen.dart';
import 'backup_screen.dart';

const int _kDailyPatientLimit = 20;

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  final _cardIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final FocusNode _nfcFocusNode = FocusNode();
  bool _isNewCard = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the NFC field as soon as the screen is rendered so the USB
    // reader can type into it immediately without the staff member clicking.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nfcFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cardIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _nfcFocusNode.dispose();
    super.dispose();
  }

  /// Returns today's queue count and the highest tokenNo seen today.
  Future<({int count, int maxToken})> _getTodayQueueStats() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('queues')
        .where('doctorId', isEqualTo: 'sahilo5657@gmail.com')
        .get();

    final today = DateTime.now();
    int count = 0;
    int maxToken = 0;

    for (var doc in snapshot.docs) {
      final ts = doc['timestamp'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        if (d.year == today.year &&
            d.month == today.month &&
            d.day == today.day) {
          count++;
          final t = doc['tokenNo'] as int? ?? 0;
          if (t > maxToken) maxToken = t;
        }
      }
    }
    return (count: count, maxToken: maxToken);
  }

  Future<int> _getNextTokenNumber() async {
    try {
      final stats = await _getTodayQueueStats();
      return stats.count == 0 ? 1 : stats.maxToken + 1;
    } catch (_) {
      return 1;
    }
  }

  Future<bool> _isDailyLimitReached() async {
    try {
      final stats = await _getTodayQueueStats();
      return stats.count >= _kDailyPatientLimit;
    } catch (_) {
      return false;
    }
  }

  // Called by the NFC TextField's onSubmitted — USB readers end their burst
  // with an Enter key, which triggers this callback once with the full card ID.
  void _handleHardwareCardTap(String cardId) async {
    if (cardId.trim().isEmpty) return;

    try {
      final cleanCardId = cardId.trim();

      final cardDoc = await FirebaseFirestore.instance
          .collection('activated_cards')
          .doc(cleanCardId)
          .get();

      if (cardDoc.exists) {
        final cardData = cardDoc.data()!;
        final name = cardData['patientName'] ?? 'Unknown Patient';
        final linkedUid = cardData['linkedUid'] ?? '';

        // Check both 'waiting' and 'serving' to prevent double entry.
        // Single where + in-memory whereIn avoids composite index.
        final existingCheck = await FirebaseFirestore.instance
            .collection('queues')
            .where('doctorId', isEqualTo: 'sahilo5657@gmail.com')
            .where('patientName', isEqualTo: name)
            .get();

        final alreadyActive = existingCheck.docs.any((d) {
          final s = d['status'] ?? '';
          return s == 'waiting' || s == 'serving';
        });

        if (alreadyActive) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("$name is already in the queue!"),
                backgroundColor: Colors.orange,
              ),
            );
            _cardIdController.clear();
            _nfcFocusNode.requestFocus();
          }
          return;
        }

        // Enforce daily patient limit before adding to queue.
        if (await _isDailyLimitReached()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Doctor's daily patient limit ($_kDailyPatientLimit) reached. No new patients today."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
            _cardIdController.clear();
            _nfcFocusNode.requestFocus();
          }
          return;
        }

        int nextToken = await _getNextTokenNumber();

        await FirebaseFirestore.instance.collection('queues').add({
          'doctorId': 'sahilo5657@gmail.com',
          'patientName': name,
          'patientId': linkedUid,
          'tokenNo': nextToken,
          'status': 'waiting',
          'queueStatus': 'Waiting',
          'etaMins': 15,
          'timestamp': FieldValue.serverTimestamp(),
          'isLinkedToApp': linkedUid.isNotEmpty,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Success! $name added as Token #$nextToken"),
              backgroundColor: Colors.green,
            ),
          );
          _cardIdController.clear();
          setState(() => _isNewCard = false);
          _nfcFocusNode.requestFocus();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Card ID not recognized. Let's register it fresh!"),
              backgroundColor: Colors.amber,
            ),
          );
          setState(() => _isNewCard = true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Database Sync Issue: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
        _nfcFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return UIShell(
      title: "Staff Dashboard",
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
          Text("Welcome, ${user?.email ?? 'Staff'}",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text("Automated NFC Reception Desk Station"),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WallDisplayScreen())),
              icon: const Icon(Icons.tv),
              label: const Text("Open Wall Display View"),
            ),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.blueGrey.shade800),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              ),
              icon: const Icon(Icons.bar_chart),
              label: const Text("View Operational Analytics Dashboard"),
            ),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.teal, width: 1.5),
                foregroundColor: Colors.teal.shade800,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              ),
              icon: const Icon(Icons.security),
              label: const Text("Database Backup & Recovery Suite"),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          const Text("Smart NFC Reader Station",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal)),
          const SizedBox(height: 8),
          const Text(
              "Tap any card onto the physical USB reader to begin automated check-in."),
          const SizedBox(height: 16),

          Card(
            color: Colors.teal.shade50,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _cardIdController,
                    focusNode: _nfcFocusNode,
                    autofocus: true,
                    // onSubmitted fires when the USB reader sends Enter after
                    // the card ID — avoids partial-ID triggers on every keystroke.
                    onSubmitted: _handleHardwareCardTap,
                    decoration: const InputDecoration(
                      labelText: "Tap Physical Card on Reader...",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (_isNewCard) ...[
                    const SizedBox(height: 16),
                    const Text("New Registration Profiles",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Patient Full Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal.shade700),
                        onPressed: () async {
                          final cardId = _cardIdController.text.trim();
                          final name = _nameController.text.trim();
                          final phone = _phoneController.text.trim();

                          if (cardId.isEmpty || name.isEmpty || phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please complete all inputs!"),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            // Check daily limit before registering new patient.
                            if (await _isDailyLimitReached()) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Doctor's daily patient limit ($_kDailyPatientLimit) reached. No new patients today."),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                              return;
                            }

                            // 1. Activate card
                            await FirebaseFirestore.instance
                                .collection('activated_cards')
                                .doc(cardId)
                                .set({
                              'cardId': cardId,
                              'patientName': name,
                              'phoneNumber': phone,
                              'status': 'active',
                              'registeredAt': FieldValue.serverTimestamp(),
                            });

                            // 2. Fetch fresh token sequence
                            int nextToken = await _getNextTokenNumber();

                            // 3. Add to queue
                            await FirebaseFirestore.instance
                                .collection('queues')
                                .add({
                              'doctorId': 'sahilo5657@gmail.com',
                              'patientName': name,
                              'patientId': '',
                              'tokenNo': nextToken,
                              'status': 'waiting',
                              'queueStatus': 'Waiting',
                              'etaMins': 15,
                              'timestamp': FieldValue.serverTimestamp(),
                              'isLinkedToApp': false,
                            });

                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "Success! Registered $name (Token #$nextToken)"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _cardIdController.clear();
                              _nameController.clear();
                              _phoneController.clear();
                              setState(() => _isNewCard = false);
                              _nfcFocusNode.requestFocus();
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text("Error: ${e.toString()}"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text("Complete New Registration"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
