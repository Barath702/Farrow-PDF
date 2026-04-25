class Note {
  final String id;
  final String pdfId;
  final int pageNumber;
  String noteText;
  final DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.pdfId,
    required this.pageNumber,
    required this.noteText,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pdfId': pdfId,
      'pageNumber': pageNumber,
      'noteText': noteText,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      pdfId: map['pdfId'] as String,
      pageNumber: map['pageNumber'] as int,
      noteText: map['noteText'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  Note copyWith({
    String? id,
    String? pdfId,
    int? pageNumber,
    String? noteText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      pdfId: pdfId ?? this.pdfId,
      pageNumber: pageNumber ?? this.pageNumber,
      noteText: noteText ?? this.noteText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
