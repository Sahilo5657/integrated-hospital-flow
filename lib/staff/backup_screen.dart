import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import '../services/audit_log_service.dart';

class BackupScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  const BackupScreen({super.key, this.firestore});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  // Local list acting as our temporary safe storage tank for exported records
  List<Map<String, dynamic>> _localBackupStorage = [];
  bool _isProcessing = false;
  String _backupTimestamp = "No backup created yet today.";

  // 1. DYNAMIC EXPORT FUNCTION (BACKUP)
  Future<void> _runSystemBackup() async {
    setState(() { _isProcessing = true; });

    try {
      // Pull all active tokens from the live queues collection
      final snapshot = await (widget.firestore ?? FirebaseFirestore.instance)
          .collection('queues')
          .where('doctorId', isEqualTo: 'sahilo5657@gmail.com')
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No data found in queue collection to back up!"), backgroundColor: Colors.orange),
          );
        }
        setState(() { _isProcessing = false; });
        return;
      }

      // Convert all database entries into local memory storage
      List<Map<String, dynamic>> temporaryTank = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        data['docId'] = doc.id; // Remember original document identity keys
        temporaryTank.add(data);
      }

      setState(() {
        _localBackupStorage = temporaryTank;
        _backupTimestamp = "Last Snapshot: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} (${_localBackupStorage.length} records safely exported)";
      });

      await AuditLogService(firestore: widget.firestore).log(
        action : AuditAction.backupExported,
        actor  : FirebaseAuth.instance.currentUser?.email ?? 'unknown',
        role   : 'staff',
        details: {'recordCount': _localBackupStorage.length},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Success! Saved ${_localBackupStorage.length} queue records locally."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backup Failed: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }

    setState(() { _isProcessing = false; });
  }

  // 2. DYNAMIC IMPORT FUNCTION (RESTORE DEMO)
  Future<void> _runSystemRestore() async {
    if (_localBackupStorage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aborted: Please create a system backup snapshot first!"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() { _isProcessing = true; });

    try {
      // Restore all elements back into your active Firestore collection loop
      for (var item in _localBackupStorage) {
        final docId = item['docId'];

        // Push the record back to the cloud
        await (widget.firestore ?? FirebaseFirestore.instance)
            .collection('queues')
            .doc(docId)
            .set(item);
      }

      await AuditLogService(firestore: widget.firestore).log(
        action : AuditAction.backupRestored,
        actor  : FirebaseAuth.instance.currentUser?.email ?? 'unknown',
        role   : 'staff',
        details: {'recordCount': _localBackupStorage.length},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Success! Restored ${_localBackupStorage.length} patient records to active screens!"), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Restore Failed: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }

    setState(() { _isProcessing = true; });
    // Quick delay check for loading visual effect polish before dismissing spinning state
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() { _isProcessing = false; });
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "System Data Protection",
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "Database Backup & Disaster Recovery",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          const Text(
            "Perform local transaction exports or restore corrupted states back into live production collections.",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // TIMESTAMP TRACKING CARD
          Card(
            color: _localBackupStorage.isNotEmpty ? Colors.green.shade50 : Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    _localBackupStorage.isNotEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: _localBackupStorage.isNotEmpty ? Colors.green : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _backupTimestamp,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // STEP A BUTTON: EXPORT BACKUP
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.cloud_download, color: Colors.blue, size: 36),
                title: const Text("Export Active Queue Data", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Downloads a safe offline copy of all existing patient tickets from Firestore."),
                trailing: const Icon(Icons.chevron_right),
                onTap: _runSystemBackup,
              ),
            ),

            const SizedBox(height: 16),

            // STEP B BUTTON: RESTORE PLAN
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.settings_backup_restore, color: Colors.teal, size: 36),
                title: const Text("Trigger Database Restore Plan", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Re-injects the saved offline copy back into Cloud Firestore to repair data loops."),
                trailing: const Icon(Icons.chevron_right),
                onTap: _runSystemRestore,
              ),
            ),
          ],
        ],
      ),
    );
  }
}