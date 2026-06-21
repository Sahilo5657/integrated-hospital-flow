import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/ui_shell.dart';
import '../services/ai_summary_service.dart';

class DoctorPatientHistoryScreen extends StatelessWidget {
  final String patientName;
  final String patientId;
  final FirebaseFirestore? firestore;

  const DoctorPatientHistoryScreen({
    super.key,
    required this.patientName,
    required this.patientId,
    this.firestore,
  });

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: patientName,
      child: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('encounters')
            .where('patientName', isEqualTo: patientName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sorted = [...(snapshot.data?.docs ?? [])]..sort((a, b) {
              final ta = (a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final tb = (b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return tb.compareTo(ta); // newest first
            });

          if (sorted.isEmpty) {
            return const Center(
              child: Text("No visit history for this patient."),
            );
          }

          final encounters = sorted
              .map((d) => {'_id': d.id, ...d.data() as Map<String, dynamic>})
              .toList();

          return Column(
            children: [
              // AI Summary banner at the top
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _openSummaryDialog(context, encounters),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      "Generate AI Summary  (${encounters.length} visit${encounters.length == 1 ? '' : 's'})",
                    ),
                  ),
                ),
              ),

              // Visit cards
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: encounters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _VisitCard(data: encounters[i], visitNumber: encounters.length - i),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openSummaryDialog(
      BuildContext context, List<Map<String, dynamic>> encounters) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AISummaryDialog(
        patientName: patientName,
        encounters: encounters,
      ),
    );
  }
}

// ── Individual visit card ────────────────────────────────────────────────────

class _VisitCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int visitNumber;
  const _VisitCard({required this.data, required this.visitNumber});

  @override
  Widget build(BuildContext context) {
    final ts = data['timestamp'] as Timestamp?;
    final date = ts?.toDate();
    final notes =
        (data['rawNotes'] ?? data['clinicalNotes'] ?? '') as String;
    final aiSummary = data['aiSummary'] as String?;
    final hasAI = aiSummary != null &&
        aiSummary.isNotEmpty &&
        !aiSummary.startsWith("Summary generation failed");

    String dateStr = '—';
    if (date != null) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      dateStr = "${date.day}/${date.month}/${date.year}  $h:$m";
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(dateStr,
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 13)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Visit $visitNumber",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            const Text("Doctor's Notes",
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              notes.isEmpty ? "No notes recorded." : notes,
              style: const TextStyle(height: 1.55, fontSize: 14),
            ),
            if (hasAI) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 13, color: Colors.purple.shade700),
                        const SizedBox(width: 4),
                        Text(
                          "AI Summary",
                          style: TextStyle(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(aiSummary,
                        style:
                            const TextStyle(fontSize: 13, height: 1.55)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── AI Summary dialog ────────────────────────────────────────────────────────

class _AISummaryDialog extends StatefulWidget {
  final String patientName;
  final List<Map<String, dynamic>> encounters;

  const _AISummaryDialog({
    required this.patientName,
    required this.encounters,
  });

  @override
  State<_AISummaryDialog> createState() => _AISummaryDialogState();
}

class _AISummaryDialogState extends State<_AISummaryDialog> {
  // 0 = last 10, 1 = last 20, 2 = all, 3 = custom
  int _option = 2;
  final _customCtrl = TextEditingController();
  bool _generating = false;
  String _status = '';
  String? _result;

  int get _total => widget.encounters.length;

  int get _count {
    return switch (_option) {
      0 => 10.clamp(1, _total),
      1 => 20.clamp(1, _total),
      2 => _total,
      3 => (int.tryParse(_customCtrl.text.trim()) ?? 0).clamp(1, _total),
      _ => _total,
    };
  }

  Future<void> _generate() async {
    final count = _count;
    final selected = widget.encounters.take(count).toList();

    // Build combined notes string with visit labels
    final buffer = StringBuffer();
    for (int i = 0; i < selected.length; i++) {
      final e = selected[i];
      final ts = e['timestamp'] as Timestamp?;
      final date = ts?.toDate();
      final dateStr = date != null
          ? "${date.day}/${date.month}/${date.year}"
          : "Unknown date";
      final notes =
          (e['rawNotes'] ?? e['clinicalNotes'] ?? '') as String;
      buffer.writeln("Visit ${selected.length - i} ($dateStr):");
      buffer.writeln(notes.isEmpty ? "(no notes)" : notes);
      if (i < selected.length - 1) buffer.writeln("\n---\n");
    }

    setState(() {
      _generating = true;
      _status = 'Connecting to AI model…';
      _result = null;
    });

    try {
      // Synthetic ID so this multi-report summary gets its own cache slot
      final cacheId = 'multi_${widget.patientName}_${count}reports';
      final summary = await AISummaryService().getSummary(
        cacheId,
        buffer.toString(),
        onStatus: (msg) {
          if (mounted) setState(() => _status = msg);
        },
      );
      if (mounted) setState(() => _result = summary);
    } catch (e) {
      if (mounted) setState(() => _result = 'Failed to generate: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      (label: 'Last 10 visits', value: 0),
      (label: 'Last 20 visits', value: 1),
      (label: 'All $_total visits', value: 2),
      (label: 'Custom number', value: 3),
    ];

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.purple),
          SizedBox(width: 8),
          Expanded(child: Text("Generate AI Summary")),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${widget.patientName} · $_total visit${_total == 1 ? '' : 's'} on record",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text("Summarize based on:",
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...options.map((o) => RadioListTile<int>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.label),
                    value: o.value,
                    // ignore: deprecated_member_use
                    groupValue: _option,
                    // ignore: deprecated_member_use
                    onChanged: _generating
                        ? null
                        : (v) => setState(() => _option = v!),
                  )),
              if (_option == 3) ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _customCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Number of visits (max $_total)",
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_generating) ...[
                const SizedBox(height: 20),
                const Center(
                    child:
                        CircularProgressIndicator(color: Colors.purple)),
                const SizedBox(height: 10),
                Center(
                  child: Text(_status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13)),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: Text(_result!,
                      style: const TextStyle(height: 1.6, fontSize: 14)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
        if (!_generating)
          FilledButton.icon(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: _count > 0 ? _generate : null,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(
              _result != null
                  ? "Regenerate"
                  : "Summarize $_count report${_count == 1 ? '' : 's'}",
            ),
          ),
      ],
    );
  }
}
