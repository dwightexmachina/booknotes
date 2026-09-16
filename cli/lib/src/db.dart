import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Resolves the database path: explicit flag > BOOKNOTES_DB env > ~/.booknotes/books.db.
String resolveDbPath(String? flagValue) {
  if (flagValue != null && flagValue.isNotEmpty) return flagValue;
  final env = Platform.environment['BOOKNOTES_DB'];
  if (env != null && env.isNotEmpty) return env;
  final home = Platform.environment['HOME'] ?? '.';
  return '$home/.booknotes/books.db';
}

/// Opens (creating if needed) the database and applies the schema.
Database openDb(String path) {
  File(path).parent.createSync(recursive: true);
  final db = sqlite3.open(path);
  db.execute('PRAGMA journal_mode = WAL;');
  db.execute('PRAGMA busy_timeout = 5000;');
  db.execute('PRAGMA foreign_keys = ON;');
  db.execute('''
    CREATE TABLE IF NOT EXISTS books (
      id           TEXT PRIMARY KEY,
      title        TEXT NOT NULL,
      author       TEXT,
      publish_year INTEGER,
      edition      TEXT,
      created_at   TEXT NOT NULL,
      updated_at   TEXT NOT NULL
    );
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS notes (
      id         TEXT PRIMARY KEY,
      book_id    TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
      section    TEXT NOT NULL DEFAULT '',
      body       TEXT NOT NULL,
      position   INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''');
  db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_book ON notes(book_id, position);');
  return db;
}
