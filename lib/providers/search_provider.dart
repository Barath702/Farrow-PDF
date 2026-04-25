import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pdf_document.dart';

/// Global search state provider with debouncing
class SearchProvider extends ChangeNotifier {
  String _query = '';
  bool _isSearching = false;
  Timer? _debounceTimer;

  String get query => _query;
  bool get isSearching => _isSearching;
  bool get hasQuery => _query.isNotEmpty;

  void setQuery(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _query = value;
      _isSearching = value.isNotEmpty;
      notifyListeners();
    });
  }

  void clearQuery() {
    _debounceTimer?.cancel();
    _query = '';
    _isSearching = false;
    notifyListeners();
  }

  /// Fuzzy match: checks if query characters appear in order in the name
  bool fuzzyMatch(String fileName, String query) {
    if (query.isEmpty) return true;

    final name = fileName.toLowerCase();
    final q = query.toLowerCase();

    // Direct contains check
    if (name.contains(q)) return true;

    // Fuzzy match: allow skipping characters at beginning
    int nameIndex = 0;
    int queryIndex = 0;

    while (nameIndex < name.length && queryIndex < q.length) {
      if (name[nameIndex] == q[queryIndex]) {
        queryIndex++;
      }
      nameIndex++;
    }

    return queryIndex == q.length;
  }

  /// Filter documents based on search query
  List<PdfDocument> filterDocuments(List<PdfDocument> documents) {
    if (_query.isEmpty) return documents;

    return documents.where((doc) {
      return fuzzyMatch(doc.fileName, _query);
    }).toList();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Search result data with match highlighting info
class SearchMatch {
  final String text;
  final List<MatchRange> matches;

  SearchMatch(this.text, this.matches);
}

/// Range of matching characters for highlighting
class MatchRange {
  final int start;
  final int end;

  MatchRange(this.start, this.end);
}

/// Utility to find match ranges in text
List<MatchRange> findMatchRanges(String text, String query) {
  if (query.isEmpty) return [];

  final ranges = <MatchRange>[];
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();

  // Find all occurrences of query as substring
  int startIndex = 0;
  while (true) {
    final index = lowerText.indexOf(lowerQuery, startIndex);
    if (index == -1) break;
    ranges.add(MatchRange(index, index + query.length));
    startIndex = index + 1;
  }

  return ranges;
}

/// Build RichText spans with highlighted matches
List<TextSpan> buildHighlightedSpans(
  String text,
  String query, {
  TextStyle? normalStyle,
  TextStyle? highlightStyle,
}) {
  if (query.isEmpty || text.isEmpty) {
    return [TextSpan(text: text, style: normalStyle)];
  }

  final ranges = findMatchRanges(text, query);
  if (ranges.isEmpty) {
    return [TextSpan(text: text, style: normalStyle)];
  }

  final spans = <TextSpan>[];
  int currentIndex = 0;

  for (final range in ranges) {
    // Add non-matching text before this range
    if (range.start > currentIndex) {
      spans.add(TextSpan(
        text: text.substring(currentIndex, range.start),
        style: normalStyle,
      ));
    }

    // Add highlighted matching text
    spans.add(TextSpan(
      text: text.substring(range.start, range.end),
      style: highlightStyle ??
          const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
    ));

    currentIndex = range.end;
  }

  // Add remaining non-matching text
  if (currentIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(currentIndex),
      style: normalStyle,
    ));
  }

  return spans;
}

/// Widget to display highlighted search text
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final spans = buildHighlightedSpans(
      text,
      query,
      normalStyle: style,
      highlightStyle: highlightStyle ??
          TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.15),
          ),
    );

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
      text: TextSpan(
        style: style ?? DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}
