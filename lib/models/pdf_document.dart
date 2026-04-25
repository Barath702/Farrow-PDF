class PdfDocument {
  final String id;
  final String filePath;
  final String fileName;
  final int fileSize;
  final int totalPages;
  int lastOpenedPage;
  DateTime? lastOpenedAt;
  String? coverThumbnailPath;
  double readingProgress;

  PdfDocument({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.totalPages,
    this.lastOpenedPage = 1,
    this.lastOpenedAt,
    this.coverThumbnailPath,
    this.readingProgress = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'totalPages': totalPages,
      'lastOpenedPage': lastOpenedPage,
      'lastOpenedAt': lastOpenedAt?.millisecondsSinceEpoch,
      'coverThumbnailPath': coverThumbnailPath,
      'readingProgress': readingProgress,
    };
  }

  factory PdfDocument.fromMap(Map<String, dynamic> map) {
    return PdfDocument(
      id: map['id'] as String,
      filePath: map['filePath'] as String,
      fileName: map['fileName'] as String,
      fileSize: map['fileSize'] as int,
      totalPages: map['totalPages'] as int,
      lastOpenedPage: map['lastOpenedPage'] as int? ?? 1,
      lastOpenedAt: map['lastOpenedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastOpenedAt'] as int)
          : null,
      coverThumbnailPath: map['coverThumbnailPath'] as String?,
      readingProgress: map['readingProgress'] as double? ?? 0.0,
    );
  }

  PdfDocument copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? fileSize,
    int? totalPages,
    int? lastOpenedPage,
    DateTime? lastOpenedAt,
    String? coverThumbnailPath,
    double? readingProgress,
  }) {
    return PdfDocument(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      totalPages: totalPages ?? this.totalPages,
      lastOpenedPage: lastOpenedPage ?? this.lastOpenedPage,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      coverThumbnailPath: coverThumbnailPath ?? this.coverThumbnailPath,
      readingProgress: readingProgress ?? this.readingProgress,
    );
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
