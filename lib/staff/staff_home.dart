import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import '../services/audit_log_service.dart';
import '../wall/wall_display_screen.dart';
import '../auth/login_screen.dart';
import 'analytics_screen.dart';
import 'backup_screen.dart';

class _DoctorOption {
  final String uid;
  final String name;
  _DoctorOption({required this.uid, required this.name});
}

class StaffHome extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  const StaffHome({super.key, this.firestore, this.auth});

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  FirebaseFirestore get _db   => widget.firestore ?? FirebaseFirestore.instance;
  FirebaseAuth      get _auth => widget.auth ?? FirebaseAuth.instance;
  String get _actor           => _auth.currentUser?.email ?? 'unknown';
  AuditLogService get _audit  => AuditLogService(firestore: widget.firestore);

  // Doctor picker
  List<_DoctorOption> _doctors = [];
  String? _selectedDoctorId;
  bool _loadingDoctors = true;

  // NFC scan
  final _cardIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nicController = TextEditingController(); // optional NIC on registration
  final FocusNode _nfcFocus = FocusNode();

  bool? _cardState; // null=idle, true=new card, false=already registered
  String? _registeredName;
  String? _lastScannedId;

  // NIC search
  final _nicSearchController = TextEditingController();
  bool _searchingNic = false;
  Map<String, dynamic>? _foundPatient;
  String? _foundPatientNic;
  bool _nicNotFound = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _nfcFocus.requestFocus());
  }

  @override
  void dispose() {
    _cardIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _nicController.dispose();
    _nicSearchController.dispose();
    _nfcFocus.dispose();
    super.dispose();
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

  void _onCardScanned(String cardId) async {
    final id = cardId.trim();
    if (id.isEmpty) return;

    try {
      final snap = await _db.collection('activated_cards').doc(id).get();

      if (snap.exists) {
        setState(() {
          _cardState = false;
          _registeredName = snap.data()?['patientName'] ?? 'Unknown';
          _lastScannedId = id;
        });
        _audit.log(
          action : AuditAction.nfcCardScanned,
          actor  : _actor,
          role   : 'staff',
          details: {'cardId': id, 'status': 'already_registered', 'patientName': _registeredName},
        );
      } else {
        setState(() {
          _cardState = true;
          _registeredName = null;
          _lastScannedId = id;
        });
        _audit.log(
          action : AuditAction.nfcCardScanned,
          actor  : _actor,
          role   : 'staff',
          details: {'cardId': id, 'status': 'new_card'},
        );
      }
      _cardIdController.clear();
      _nfcFocus.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
        _nfcFocus.requestFocus();
      }
    }
  }

  void _resetScan() {
    setState(() {
      _cardState = null;
      _registeredName = null;
      _lastScannedId = null;
    });
    _cardIdController.clear();
    _nameController.clear();
    _phoneController.clear();
    _nicController.clear();
    _nfcFocus.requestFocus();
  }

  Future<void> _searchByNic() async {
    final nic = _nicSearchController.text.trim();
    if (nic.isEmpty) return;

    setState(() {
      _searchingNic = true;
      _foundPatient = null;
      _foundPatientNic = null;
      _nicNotFound = false;
    });

    try {
      final doc = await _db.collection('patients').doc(nic).get();
      if (mounted) {
        if (doc.exists && doc.data() != null) {
          setState(() {
            _foundPatient = doc.data();
            _foundPatientNic = nic;
            _searchingNic = false;
          });
          _audit.log(
            action : AuditAction.patientLookupNic,
            actor  : _actor,
            role   : 'staff',
            details: {'nic': nic, 'result': 'found'},
          );
        } else {
          setState(() {
            _nicNotFound = true;
            _searchingNic = false;
          });
          _audit.log(
            action : AuditAction.patientLookupNic,
            actor  : _actor,
            role   : 'staff',
            details: {'nic': nic, 'result': 'not_found'},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Search error: $e"), backgroundColor: Colors.red),
        );
        setState(() => _searchingNic = false);
      }
    }
  }

  // Register a new NFC card for an existing patient found by NIC
  Future<void> _registerNewCardForNicPatient(String cardId) async {
    final patient = _foundPatient!;
    final nic = _foundPatientNic!;
    final name = patient['patientName'] as String? ?? '';
    final phone = patient['phoneNumber'] as String? ?? '';

    try {
      await _db.collection('activated_cards').doc(cardId).set({
        'cardId': cardId,
        'patientName': name,
        'phoneNumber': phone,
        'nic': nic,
        'status': 'active',
        'registeredAt': FieldValue.serverTimestamp(),
      });

      await _audit.log(
        action : AuditAction.nfcCardLinkedNic,
        actor  : _actor,
        role   : 'staff',
        details: {'cardId': cardId, 'nic': nic, 'patientName': name},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("New card registered for $name."),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _foundPatient = null;
          _foundPatientNic = null;
          _nicNotFound = false;
        });
        _nicSearchController.clear();
        _resetScan();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return UIShell(
      title: "Reception",
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: "Logout",
          onPressed: () async {
            await _audit.log(
              action : AuditAction.userLogout,
              actor  : _actor,
              role   : 'staff',
            );
            await _auth.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            }
          },
        ),
      ],
      child: ListView(
        children: [
          Text(
            "Welcome, ${user?.email ?? 'Staff'}",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text("Reception Desk"),
          const SizedBox(height: 16),

          // ── Doctor picker ──────────────────────────────────────────────
          _loadingDoctors
              ? const Center(child: CircularProgressIndicator())
              : _doctors.isEmpty
                  ? const Text(
                      "No doctors found in the system.",
                      style: TextStyle(color: Colors.grey),
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
                      hint: const Text("Choose a doctor"),
                    ),
          const SizedBox(height: 20),

          // ── Quick-access buttons ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _selectedDoctorId == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WallDisplayScreen(
                            doctorId: _selectedDoctorId!,
                          ),
                        ),
                      ),
              icon: const Icon(Icons.tv),
              label: const Text("Open Wall Display"),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade800),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              ),
              icon: const Icon(Icons.bar_chart),
              label: const Text("Operational Analytics"),
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
              label: const Text("Database Backup & Recovery"),
            ),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),

          // ── NFC card registration section ────────────────────────────
          const Text(
            "NFC Card Registration",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tap a card on the reader to register a new patient. "
            "Patients check themselves into the queue at the NFC station.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          Card(
            color: Colors.teal.shade50,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Invisible keyboard-input field for USB NFC reader
                  TextField(
                    controller: _cardIdController,
                    focusNode: _nfcFocus,
                    autofocus: true,
                    onSubmitted: _onCardScanned,
                    decoration: const InputDecoration(
                      labelText: "Tap card on reader...",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.nfc),
                    ),
                  ),

                  // Already registered ─────────────────────────────────
                  if (_cardState == false && _registeredName != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade700, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Card registered — $_registeredName",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Patient should tap this card at the NFC check-in station to join the queue.",
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _resetScan,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text("Scan another card"),
                    ),
                  ],

                  // New card — registration form ───────────────────────
                  if (_cardState == true) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.fiber_new, color: Colors.teal),
                        const SizedBox(width: 6),
                        const Text(
                          "New card — enter patient details",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Patient Full Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nicController,
                      decoration: const InputDecoration(
                        labelText: "NIC / National ID (optional)",
                        border: OutlineInputBorder(),
                        helperText:
                            "Lets patient recover data if card is lost",
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.teal.shade700),
                            onPressed: () async {
                              final cardId = _lastScannedId;
                              final name = _nameController.text.trim();
                              final phone = _phoneController.text.trim();
                              final nic = _nicController.text.trim();

                              if (cardId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Tap the card on the reader again first."),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                _nfcFocus.requestFocus();
                                return;
                              }

                              if (name.isEmpty || phone.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text("Name and phone are required."),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              final messenger =
                                  ScaffoldMessenger.of(context);
                              try {
                                final batch = _db.batch();

                                // Always create the activated_cards entry
                                final cardRef = _db
                                    .collection('activated_cards')
                                    .doc(cardId);
                                batch.set(cardRef, {
                                  'cardId': cardId,
                                  'patientName': name,
                                  'phoneNumber': phone,
                                  if (nic.isNotEmpty) 'nic': nic,
                                  'status': 'active',
                                  'registeredAt':
                                      FieldValue.serverTimestamp(),
                                });

                                // If NIC provided, upsert patients/{nic}
                                if (nic.isNotEmpty) {
                                  final patientRef =
                                      _db.collection('patients').doc(nic);
                                  batch.set(
                                    patientRef,
                                    {
                                      'nic': nic,
                                      'patientName': name,
                                      'phoneNumber': phone,
                                      'updatedAt':
                                          FieldValue.serverTimestamp(),
                                    },
                                    SetOptions(merge: true),
                                  );
                                }

                                await batch.commit();

                                await _audit.log(
                                  action : AuditAction.nfcCardRegistered,
                                  actor  : _actor,
                                  role   : 'staff',
                                  details: {
                                    'cardId'     : cardId,
                                    'patientName': name,
                                    if (nic.isNotEmpty) 'nic': nic,
                                  },
                                );

                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          "Card registered for $name."),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _resetScan();
                                }
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text("Error: $e"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.card_membership),
                            label: const Text("Register Card"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: _resetScan,
                          child: const Text("Cancel"),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),

          // ── NIC search section ────────────────────────────────────────
          const Text(
            "Find Patient by NIC",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
          const SizedBox(height: 4),
          const Text(
            "If a patient lost their card, search by National ID to retrieve their record and register a new card.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          Card(
            color: Colors.indigo.shade50,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nicSearchController,
                          decoration: const InputDecoration(
                            labelText: "National ID (NIC)",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.indigo.shade700),
                        onPressed: _searchingNic ? null : _searchByNic,
                        icon: _searchingNic
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search),
                        label: const Text("Search"),
                      ),
                    ],
                  ),

                  // Patient found ───────────────────────────────────────
                  if (_foundPatient != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Patient Found",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              "Name: ${_foundPatient!['patientName'] ?? '—'}"),
                          Text(
                              "Phone: ${_foundPatient!['phoneNumber'] ?? '—'}"),
                          Text("NIC: $_foundPatientNic"),
                          const SizedBox(height: 12),
                          const Text(
                            "To register a new card for this patient, scan the new card in the NFC section above, then tap the button below.",
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700),
                              onPressed: _lastScannedId == null
                                  ? null
                                  : () => _registerNewCardForNicPatient(
                                      _lastScannedId!),
                              icon: const Icon(Icons.add_card),
                              label: Text(_lastScannedId == null
                                  ? "Scan a new card first"
                                  : "Register New Card (${_lastScannedId!.substring(0, 4)}...)"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Not found ───────────────────────────────────────────
                  if (_nicNotFound) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "No patient found with that NIC. Register them via the card section above.",
                            ),
                          ),
                        ],
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
