class ReadingHistory {
  final String id;
  final String pdfId;
  final int pageNumber;
  final int totalPages;
  final DateTime openedAt;

  ReadingHistory({
    required this.id,
    required this.pdfId,
    required this.pageNumber,
    required this.totalPages,
    DateTime? openedAt,
  }) : openedAt = openedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pdfId': pdfId,
      'pageNumber': pageNumber,
      'totalPages': totalPages,
      'openedAt': openedAt.millisecondsSinceEpoch,
    };
  }

  factory ReadingHistory.fromMap(Map<String, dynamic> map) {
    return ReadingHistory(
      id: map['id'] as String,
      pdfId: map['pdfId'] as String,
      pageNumber: map['pageNumber'] as int,
      totalPages: map['totalPages'] as int? ?? 1,
      openedAt: DateTime.fromMillisecondsSinceEpoch(map['openedAt'] as int),
    );
  }

  ReadingHistory copyWith({
    String? id,
    String? pdfId,
    int? pageNumber,
    int? totalPages,
    DateTime? openedAt,
  }) {
    return ReadingHistory(
      id: id ?? this.id,
      pdfId: pdfId ?? this.pdfId,
      pageNumber: pageNumber ?? this.pageNumber,
      totalPages: totalPages ?? this.totalPages,
      openedAt: openedAt ?? this.openedAt,
    );
  }
}
