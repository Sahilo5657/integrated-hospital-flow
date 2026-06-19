import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AISummaryService {
  // Your specific Hugging Face model URL
  final String _apiUrl = "https://api-inference.huggingface.co/models/sahilo56/my-medical-summarizer";

  // Your Hugging Face Access Token
  final String _token = "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";

  Future<String> getSummary(String encounterId, String clinicalNotes) async {
    // 1. Check if summary already exists in Firestore to save API costs/time
    final doc = await FirebaseFirestore.instance
        .collection('summaries')
        .where('encounterId', isEqualTo: encounterId)
        .get();

    if (doc.docs.isNotEmpty) {
      return doc.docs.first['summaryText'];
    }

    // 2. Call the Hugging Face Inference API
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        "Authorization": "Bearer $_token",
        "Content-Type": "application/json",
      },
      // Hugging Face expects the key "inputs"
      body: jsonEncode({"inputs": clinicalNotes}),
    );

    if (response.statusCode == 200) {
      // Hugging Face returns a List of maps for summarization models
      final List<dynamic> result = jsonDecode(response.body);
      final String summary = result[0]['summary_text'] ?? "No summary generated.";

      // 3. Save to Firestore for future reference [cite: 50]
      await FirebaseFirestore.instance.collection('summaries').add({
        'encounterId': encounterId,
        'summaryText': summary,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return summary;
    } else {
      // If the model is still loading, Hugging Face returns a 503 error
      throw Exception("AI Summarization failed: ${response.body}");
    }
  }
}