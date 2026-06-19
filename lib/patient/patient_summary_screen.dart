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
      final summary = await AISummaryService()
          .getSummary(widget.encounterId, widget.clinicalNotes);
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
      title: "Visit Summary",
      child: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Generating AI summary..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.purple),
                          const SizedBox(width: 8),
                          const Text(
                            "AI Clinical Summary",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        _summary ?? "No summary available.",
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
