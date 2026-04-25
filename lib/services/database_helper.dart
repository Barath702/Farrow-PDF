import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static const String _databaseName = 'redreader.db';
  static const int _databaseVersion = 3;

  static const String tablePdfDocuments = 'pdf_documents';
  static const String tableBookmarks = 'bookmarks';
  static const String tableNotes = 'notes';
  static const String tableReadingHistory = 'reading_history';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop platforms
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // PDF Documents table
    await db.execute('''
      CREATE TABLE $tablePdfDocuments (
        id TEXT PRIMARY KEY,
        filePath TEXT NOT NULL,
        fileName TEXT NOT NULL,
        fileSize INTEGER NOT NULL,
        totalPages INTEGER NOT NULL,
        lastOpenedPage INTEGER DEFAULT 1,
        lastOpenedAt INTEGER,
        coverThumbnailPath TEXT,
        readingProgress REAL DEFAULT 0.0
      )
    ''');

    // Bookmarks table
    await db.execute('''
      CREATE TABLE $tableBookmarks (
        id TEXT PRIMARY KEY,
        pdfId TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        pageTitle TEXT,
        thumbnailPath TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (pdfId) REFERENCES $tablePdfDocuments(id) ON DELETE CASCADE,
        UNIQUE(pdfId, pageNumber)
      )
    ''');

    // Notes table
    await db.execute('''
      CREATE TABLE $tableNotes (
        id TEXT PRIMARY KEY,
        pdfId TEXT NOT NULL,
        pageNumber INTEGER NOT NULL,
        noteText TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (pdfId) REFERENCES $tablePdfDocuments(id) ON DELETE CASCADE
      )
    ''');

    // Reading History table - using pdfId as unique key (one entry per PDF)
    await db.execute('''
      CREATE TABLE $tableReadingHistory (
        id TEXT PRIMARY KEY,
        pdfId TEXT NOT NULL UNIQUE,
        pageNumber INTEGER NOT NULL,
        totalPages INTEGER NOT NULL DEFAULT 1,
        openedAt INTEGER NOT NULL,
        FOREIGN KEY (pdfId) REFERENCES $tablePdfDocuments(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX idx_bookmarks_pdfId ON $tableBookmarks(pdfId)');
    await db.execute('CREATE INDEX idx_notes_pdfId ON $tableNotes(pdfId)');
    await db.execute(
        'CREATE INDEX idx_history_pdfId ON $tableReadingHistory(pdfId)');
    await db.execute(
        'CREATE INDEX idx_history_openedAt ON $tableReadingHistory(openedAt)');
  }

  Future<void> close() async {
    final Database db = await database;
    await db.close();
    _database = null;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration: Add unique constraint on pdfId by recreating the table
      await db.execute('''
        CREATE TABLE ${tableReadingHistory}_new (
          id TEXT PRIMARY KEY,
          pdfId TEXT NOT NULL UNIQUE,
          pageNumber INTEGER NOT NULL,
          openedAt INTEGER NOT NULL,
          FOREIGN KEY (pdfId) REFERENCES $tablePdfDocuments(id) ON DELETE CASCADE
        )
      ''');

      // Keep only the most recent entry per pdfId
      await db.execute('''
        INSERT INTO ${tableReadingHistory}_new (id, pdfId, pageNumber, openedAt)
        SELECT id, pdfId, pageNumber, openedAt FROM (
          SELECT id, pdfId, pageNumber, openedAt,
                 ROW_NUMBER() OVER (PARTITION BY pdfId ORDER BY openedAt DESC) as rn
          FROM $tableReadingHistory
        ) WHERE rn = 1
      ''');

      await db.execute('DROP TABLE $tableReadingHistory');
      await db.execute('ALTER TABLE ${tableReadingHistory}_new RENAME TO $tableReadingHistory');

      // Recreate indexes
      await db.execute(
          'CREATE INDEX idx_history_pdfId ON $tableReadingHistory(pdfId)');
      await db.execute(
          'CREATE INDEX idx_history_openedAt ON $tableReadingHistory(openedAt)');
    }

    if (oldVersion < 3) {
      // Migration: Add totalPages column
      await db.execute('ALTER TABLE $tableReadingHistory ADD COLUMN totalPages INTEGER NOT NULL DEFAULT 1');
    }
  }
}
