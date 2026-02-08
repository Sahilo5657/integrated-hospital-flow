import '../models/queue_models.dart';

class DemoData {
  static List<QueueItem> initialQueue() {
    return [
      QueueItem(tokenNo: 12, patientName: "Ayesha", patientId: "P-1021", etaMins: 0, status: QueueStatus.serving),
      QueueItem(tokenNo: 13, patientName: "Hamza", patientId: "P-1044", etaMins: 6),
      QueueItem(tokenNo: 14, patientName: "Ali", patientId: "P-1099", etaMins: 12),
      QueueItem(tokenNo: 15, patientName: "Fatima", patientId: "P-1107", etaMins: 18),
    ];
  }

  static String aiSummarySample() {
    return "AI Summary (Demo):\n\n"
        "• Complaint: Headache for 2 days\n"
        "• Vitals: Stable\n"
        "• Assessment: Likely tension headache\n"
        "• Plan: Hydration, rest, analgesic if needed, follow-up if symptoms persist.";
  }
}
