import 'package:flutter/material.dart';
import '../common/ui_shell.dart';
import '../services/ai_summary_service.dart';

class PatientSummaryScreen extends StatefulWidget {
  final String encounterId;
  final String clinicalNotes;
  final String? cachedSummary;

  const PatientSummaryScreen({
    super.key,
    required this.encounterId,
    required this.clinicalNotes,
    this.cachedSummary,
  });

  @override
  State<PatientSummaryScreen> createState() => _PatientSummaryScreenState();
}

class _PatientSummaryScreenState extends State<PatientSummaryScreen> {
  String? _summary;
  bool _isLoading = true;
  String _statusMessage = "Generating AI summary...";

  @override
  void initState() {
    super.initState();
    if (widget.cachedSummary != null && widget.cachedSummary!.isNotEmpty) {
      _summary = widget.cachedSummary;
      _isLoading = false;
    } else {
      _fetchSummary();
    }
  }

  void _fetchSummary() async {
    try {
      final summary = await AISummaryService().getSummary(
        widget.encounterId,
        widget.clinicalNotes,
        onStatus: (msg) {
          if (mounted) setState(() => _statusMessage = msg);
        },
      );
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _summary = "Could not generate summary: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UIShell(
      title: "Visit Report",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Doctor's original report ──────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description_outlined,
                            color: Colors.blueGrey.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "Doctor's Report",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      widget.clinicalNotes.isNotEmpty
                          ? widget.clinicalNotes
                          : "No notes were recorded for this visit.",
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── AI Summary ────────────────────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.purple, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "AI Clinical Summary",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    if (_isLoading) ...[
                      const Center(child: CircularProgressIndicator(
                          color: Colors.purple)),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ] else
                      Text(
                        _summary ?? "No summary available.",
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "AI summaries are assistive only and must not replace clinical judgment.",
                              style: TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
