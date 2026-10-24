class IngestionLogModel {
  final String id;
  final DateTime timestamp;
  final String? sender;
  final String rawMessageSnippet;
  final String status; // 'success', 'duplicate', 'pending_review', 'rejected_otp', 'parse_error'
  final int? parsedAmountSantims;
  final double? confidenceScore;
  final String? errorMessage;

  const IngestionLogModel({
    required this.id,
    required this.timestamp,
    this.sender,
    required this.rawMessageSnippet,
    required this.status,
    this.parsedAmountSantims,
    this.confidenceScore,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sender': sender,
      'raw_message_snippet': rawMessageSnippet,
      'status': status,
      'parsed_amount_santims': parsedAmountSantims,
      'confidence_score': confidenceScore,
      'error_message': errorMessage,
    };
  }

  factory IngestionLogModel.fromMap(Map<String, dynamic> map) {
    return IngestionLogModel(
      id: map['id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      sender: map['sender'] as String?,
      rawMessageSnippet: map['raw_message_snippet'] as String,
      status: map['status'] as String,
      parsedAmountSantims: map['parsed_amount_santims'] as int?,
      confidenceScore: (map['confidence_score'] as num?)?.toDouble(),
      errorMessage: map['error_message'] as String?,
    );
  }
}
