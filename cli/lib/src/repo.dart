import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String _now() => DateTime.now().toUtc().toIso8601String();

/// Canonical word-count rule used everywhere (CLI, API, UI):
/// trim, then count runs of non-whitespace.
int wordCount(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
  @override
  String toString() => message;
}

class AmbiguousException implements Exception {
  final String message;
  AmbiguousException(this.message);
  @override
  String toString() => message;
}

Map<String, Object?> _bookMap(Row r) => {
      'id': r['id'],
      'title': r['title'],
      'author': r['author'],
      'publish_year': r['publish_year'],
      'edition': r['edition'],
      'created_at': r['created_at'],
      'updated_at': r['updated_at'],
    };

Map<String, Object?> _noteMap(Row r) => {
      'id': r['id'],
      'book_id': r['book_id'],
      'section': r['section'],
      'body': r['body'],
      'position': r['position'],
      'word_count': wordCount(r['body'] as String),
      'created_at': r['created_at'],
      'updated_at': r['updated_at'],
    };

// ---------- books ----------

/// All books ordered by title, each with note_count and aggregate word_count.
List<Map<String, Object?>> listBooks(Database db) {
  final books =
      db.select('SELECT * FROM books ORDER BY title COLLATE NOCASE');
  final notes = db.select('SELECT book_id, body FROM notes');
  final noteCounts = <String, int>{};
  final wordCounts = <String, int>{};
  for (final n in notes) {
    final id = n['book_id'] as String;
    noteCounts[id] = (noteCounts[id] ?? 0) + 1;
    wordCounts[id] = (wordCounts[id] ?? 0) + wordCount(n['body'] as String);
  }
  return [
    for (final r in books)
      {
        ..._bookMap(r),
        'note_count': noteCounts[r['id']] ?? 0,
        'word_count': wordCounts[r['id']] ?? 0,
      }
  ];
}

/// Resolves a book reference: exact UUID, unique UUID prefix, or unique
/// case-insensitive title substring. Throws NotFound/Ambiguous otherwise.
Map<String, Object?> resolveBook(Database db, String ref) {
  var rows = db.select('SELECT * FROM books WHERE id = ?', [ref]);
  if (rows.isEmpty) {
    rows = db.select("SELECT * FROM books WHERE id LIKE ? || '%'", [ref]);
  }
  if (rows.isEmpty) {
    rows = db.select(
        "SELECT * FROM books WHERE title LIKE '%' || ? || '%' COLLATE NOCASE",
        [ref]);
  }
  if (rows.isEmpty) {
    throw NotFoundException(
        'No book matches "$ref" (tried UUID, UUID prefix, title substring).');
  }
  if (rows.length > 1) {
    final options = rows
        .map((r) => '  ${(r['id'] as String).substring(0, 8)}  ${r['title']}')
        .join('\n');
    throw AmbiguousException(
        '"$ref" matches ${rows.length} books; use a UUID prefix instead:\n$options');
  }
  return _bookMap(rows.first);
}

/// Book with computed counts, without its notes.
Map<String, Object?> bookWithCounts(Database db, String bookId) {
  final r = db.select('SELECT * FROM books WHERE id = ?', [bookId]).first;
  final notes =
      db.select('SELECT body FROM notes WHERE book_id = ?', [bookId]);
  var words = 0;
  for (final n in notes) {
    words += wordCount(n['body'] as String);
  }
  return {..._bookMap(r), 'note_count': notes.length, 'word_count': words};
}

Map<String, Object?> createBook(
  Database db, {
  required String title,
  String? author,
  int? publishYear,
  String? edition,
}) {
  final id = _uuid.v4();
  final now = _now();
  db.execute(
    'INSERT INTO books (id, title, author, publish_year, edition, created_at, updated_at) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    [id, title, author, publishYear, edition, now, now],
  );
  return bookWithCounts(db, id);
}

/// Updates only the provided fields. Passing an empty string for author or
/// edition clears the field; `clearYear` clears publish_year.
Map<String, Object?> updateBook(
  Database db,
  String bookId, {
  String? title,
  String? author,
  int? publishYear,
  bool clearYear = false,
  String? edition,
}) {
  final sets = <String>[];
  final args = <Object?>[];
  if (title != null) {
    sets.add('title = ?');
    args.add(title);
  }
  if (author != null) {
    sets.add('author = ?');
    args.add(author.isEmpty ? null : author);
  }
  if (publishYear != null || clearYear) {
    sets.add('publish_year = ?');
    args.add(publishYear);
  }
  if (edition != null) {
    sets.add('edition = ?');
    args.add(edition.isEmpty ? null : edition);
  }
  if (sets.isEmpty) {
    throw ArgumentError('Nothing to update: pass at least one field flag.');
  }
  sets.add('updated_at = ?');
  args.add(_now());
  args.add(bookId);
  db.execute('UPDATE books SET ${sets.join(', ')} WHERE id = ?', args);
  return bookWithCounts(db, bookId);
}

/// Deletes the book; its notes go with it via ON DELETE CASCADE.
void deleteBook(Database db, String bookId) {
  db.execute('DELETE FROM books WHERE id = ?', [bookId]);
}

// ---------- notes ----------

List<Map<String, Object?>> listNotes(Database db, String bookId) {
  final rows = db.select(
      'SELECT * FROM notes WHERE book_id = ? ORDER BY position', [bookId]);
  return [for (final r in rows) _noteMap(r)];
}

/// Resolves a note by exact UUID or unique UUID prefix.
Map<String, Object?> resolveNote(Database db, String ref) {
  var rows = db.select('SELECT * FROM notes WHERE id = ?', [ref]);
  if (rows.isEmpty) {
    rows = db.select("SELECT * FROM notes WHERE id LIKE ? || '%'", [ref]);
  }
  if (rows.isEmpty) {
    throw NotFoundException('No note matches "$ref" (UUID or UUID prefix).');
  }
  if (rows.length > 1) {
    throw AmbiguousException(
        '"$ref" matches ${rows.length} notes; use a longer UUID prefix.');
  }
  return _noteMap(rows.first);
}

/// Appends a note at the end of the book's ordering.
Map<String, Object?> createNote(
  Database db, {
  required String bookId,
  required String section,
  required String body,
}) {
  final id = _uuid.v4();
  final now = _now();
  final max = db.select(
      'SELECT COALESCE(MAX(position), 0) AS m FROM notes WHERE book_id = ?',
      [bookId]).first['m'] as int;
  db.execute(
    'INSERT INTO notes (id, book_id, section, body, position, created_at, updated_at) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    [id, bookId, section, body, max + 1, now, now],
  );
  return resolveNote(db, id);
}

Map<String, Object?> updateNote(
  Database db,
  String noteId, {
  String? section,
  String? body,
}) {
  final sets = <String>[];
  final args = <Object?>[];
  if (section != null) {
    sets.add('section = ?');
    args.add(section);
  }
  if (body != null) {
    sets.add('body = ?');
    args.add(body);
  }
  if (sets.isEmpty) {
    throw ArgumentError('Nothing to update: pass --section and/or a body.');
  }
  sets.add('updated_at = ?');
  args.add(_now());
  args.add(noteId);
  db.execute('UPDATE notes SET ${sets.join(', ')} WHERE id = ?', args);
  return resolveNote(db, noteId);
}

void _renumber(Database db, String bookId, List<String> orderedIds) {
  final now = _now();
  for (var i = 0; i < orderedIds.length; i++) {
    db.execute('UPDATE notes SET position = ?, updated_at = ? WHERE id = ?',
        [i + 1, now, orderedIds[i]]);
  }
}

/// Moves a note to 1-based [newPosition] within its book (clamped to range),
/// then renumbers the book's notes to a contiguous 1..n.
Map<String, Object?> moveNote(Database db, String noteId, int newPosition) {
  final note = resolveNote(db, noteId);
  final bookId = note['book_id'] as String;
  db.execute('BEGIN');
  try {
    final ids = db
        .select('SELECT id FROM notes WHERE book_id = ? ORDER BY position',
            [bookId])
        .map((r) => r['id'] as String)
        .toList();
    ids.remove(noteId);
    final index = (newPosition - 1).clamp(0, ids.length);
    ids.insert(index, noteId);
    _renumber(db, bookId, ids);
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
  return resolveNote(db, noteId);
}

/// Deletes a note and closes the gap in its book's ordering.
void deleteNote(Database db, String noteId) {
  final note = resolveNote(db, noteId);
  final bookId = note['book_id'] as String;
  db.execute('BEGIN');
  try {
    db.execute('DELETE FROM notes WHERE id = ?', [noteId]);
    final ids = db
        .select('SELECT id FROM notes WHERE book_id = ? ORDER BY position',
            [bookId])
        .map((r) => r['id'] as String)
        .toList();
    _renumber(db, bookId, ids);
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
