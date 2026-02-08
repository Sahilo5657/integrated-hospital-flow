class QueueItem {
  final int tokenNo;
  final String patientName;
  final String patientId;
  final int etaMins;
  QueueStatus status;

  QueueItem({
    required this.tokenNo,
    required this.patientName,
    required this.patientId,
    required this.etaMins,
    this.status = QueueStatus.waiting,
  });
}

enum QueueStatus { waiting, serving, done, skipped }

extension QueueStatusX on QueueStatus {
  String get label {
    switch (this) {
      case QueueStatus.waiting:
        return "Waiting";
      case QueueStatus.serving:
        return "Serving";
      case QueueStatus.done:
        return "Done";
      case QueueStatus.skipped:
        return "Skipped";
    }
  }
}
