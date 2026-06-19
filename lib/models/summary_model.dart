import 'package:cloud_firestore/cloud_firestore.dart';

class SummaryModel {
  final String id;
  final String encounterId;
  final String summaryText;
  final DateTime timestamp;

  SummaryModel({
    required this.id,
    required this.encounterId,
    required this.summaryText,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'encounterId': encounterId,
    'summaryText': summaryText,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}