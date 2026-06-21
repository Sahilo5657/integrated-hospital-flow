import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AISummaryService {
  // facebook/bart-large-cnn: purpose-built summarization model, always deployed
  // on HF's TGI servers, always warm, no license gate, free on hf-inference router.
  final String _apiUrl =
      "https://router.huggingface.co/hf-inference/models/facebook/bart-large-cnn";
  final String _token = "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";
  final FirebaseFirestore _firestore;
  final http.Client _client;

  AISummaryService({FirebaseFirestore? firestore, http.Client? client})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _client = client ?? http.Client();

  Future<String> getSummary(
    String encounterId,
    String clinicalNotes, {
    void Function(String status)? onStatus,
  }) async {
    // Return cached summary from Firestore if available.
    try {
      final existing = await _firestore
          .collection('summaries')
          .where('encounterId', isEqualTo: encounterId)
          .get()
          .timeout(const Duration(seconds: 10));
      if (existing.docs.isNotEmpty) {
        return existing.docs.first['summaryText'] as String;
      }
    } catch (_) {
      // Cache miss or timeout — fall through to API call.
    }

    onStatus?.call("Generating AI summary...");

    String? summary;
    // 3 retries for transient network failures; bart-large-cnn is always warm.
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        onStatus?.call("Retrying... (${attempt + 1}/3)");
        await Future.delayed(const Duration(seconds: 5));
      }

      late http.Response response;
      try {
        response = await _client
            .post(
              Uri.parse(_apiUrl),
              headers: {
                "Authorization": "Bearer $_token",
                "Content-Type": "application/json",
              },
              // bart-large-cnn uses the summarization task format:
              // { "inputs": "...", "parameters": { ... } }
              body: jsonEncode({
                "inputs": clinicalNotes,
                "parameters": {
                  "max_length": 200,
                  "min_length": 40,
                  "do_sample": false,
                },
              }),
            )
            .timeout(const Duration(seconds: 40));
      } catch (e) {
        if (attempt == 2) {
          throw Exception(
              "Cannot reach AI service. Check your internet connection. Detail: $e");
        }
        continue;
      }

      if (response.statusCode == 200) {
        // Summarization models return: [{"summary_text": "..."}]
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          summary = (decoded[0]['summary_text'] as String?)?.trim();
          if (summary != null && summary.isNotEmpty) break;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        String hfError = "Authorization failed";
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          hfError = body['error'] as String? ?? hfError;
        } catch (_) {}
        throw Exception(
            "HuggingFace token error (${response.statusCode}): $hfError. "
            "Ensure your token has 'Make calls to the serverless Inference API' permission enabled at hf.co/settings/tokens.");
      } else {
        String hfError = response.body;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          hfError = (body['error'] as String?) ?? hfError;
        } catch (_) {}
        if (attempt == 2) {
          throw Exception(
              "AI Summarization failed (${response.statusCode}): $hfError");
        }
      }
    }

    if (summary == null || summary.isEmpty) {
      throw Exception("The AI model did not return a summary. Please try again.");
    }

    // 1. Store in dedicated summaries collection (primary cache for future calls).
    await _firestore.collection('summaries').add({
      'encounterId': encounterId,
      'summaryText': summary,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Write back to the encounter document so the doctor queue's in-screen cache hits.
    try {
      await _firestore.collection('encounters').doc(encounterId).update({
        'aiSummary': summary,
      });
    } catch (_) {
      // Non-fatal: summaries collection is the primary cache.
    }

    return summary;
  }
}
