class Bookmark {
  final String id;
  final String pdfId;
  final int pageNumber;
  final String? pageTitle;
  String? thumbnailPath;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.pdfId,
    required this.pageNumber,
    this.pageTitle,
    this.thumbnailPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pdfId': pdfId,
      'pageNumber': pageNumber,
      'pageTitle': pageTitle,
      'thumbnailPath': thumbnailPath,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      pdfId: map['pdfId'] as String,
      pageNumber: map['pageNumber'] as int,
      pageTitle: map['pageTitle'] as String?,
      thumbnailPath: map['thumbnailPath'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  Bookmark copyWith({
    String? id,
    String? pdfId,
    int? pageNumber,
    String? pageTitle,
    String? thumbnailPath,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      pdfId: pdfId ?? this.pdfId,
      pageNumber: pageNumber ?? this.pageNumber,
      pageTitle: pageTitle ?? this.pageTitle,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
