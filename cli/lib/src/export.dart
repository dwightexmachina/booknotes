import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'repo.dart';

const _encoder = JsonEncoder.withIndent('  ');

/// Writes a static snapshot of the whole database, shaped exactly like the
/// `serve` API responses (see docs/api.md):
///
///   <dir>/books.json        == GET /api/books
///   <dir>/books/<id>.json   == GET /api/books/<id>
///
/// This is what the Flutter web app reads when built with
/// `--dart-define=STATIC_DATA=true`, so GitHub Pages needs no server.
/// Returns the number of books written.
int exportStatic(Database db, String dir) {
  final root = Directory(dir);
  final booksDir = Directory('${root.path}/books');
  // Stale per-book files would keep deleted books alive on the site.
  if (booksDir.existsSync()) booksDir.deleteSync(recursive: true);
  booksDir.createSync(recursive: true);

  final books = listBooks(db);
  File('${root.path}/books.json').writeAsStringSync(_encoder.convert(books));

  for (final b in books) {
    final id = b['id'] as String;
    File('${booksDir.path}/$id.json').writeAsStringSync(
      _encoder.convert({...b, 'notes': listNotes(db, id)}),
    );
  }
  return books.length;
}
