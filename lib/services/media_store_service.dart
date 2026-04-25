import 'dart:io';
import 'package:flutter/services.dart';
import 'file_scanner_service.dart';

/// Service to query PDF files from Android MediaStore via platform channel
class MediaStoreService {
  static const MethodChannel _channel = MethodChannel('pdf_query_channel');

  /// Query all PDF files from MediaStore (Android only)
  static Future<List<ScannedPdfFile>> queryPdfFiles() async {
    if (!Platform.isAndroid) {
      return []; // MediaStore is Android only
    }

    try {
      final List<dynamic>? result = await _channel.invokeMethod('getAllPdfs');

      if (result == null) return [];

      return result.map((item) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        return ScannedPdfFile(
          filePath: map['filePath'] as String,
          fileName: map['fileName'] as String,
          fileSize: (map['fileSize'] as num).toInt(),
          lastModified: DateTime.fromMillisecondsSinceEpoch((map['dateModified'] as num).toInt() * 1000),
        );
      }).toList();
    } on PlatformException catch (e) {
      print('MediaStore query failed: ${e.message}');
      return [];
    } catch (e) {
      print('MediaStore query error: $e');
      return [];
    }
  }
}
