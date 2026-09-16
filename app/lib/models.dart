class Note {
  final String id;
  final String bookId;
  final String section;
  final String body;
  final int position;
  final int wordCount;

  Note.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        bookId = j['book_id'] as String,
        section = j['section'] as String,
        body = j['body'] as String,
        position = j['position'] as int,
        wordCount = j['word_count'] as int;
}

class Book {
  final String id;
  final String title;
  final String? author;
  final int? publishYear;
  final String? edition;
  final int noteCount;
  final int wordCount;
  final List<Note> notes;

  Book.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        author = j['author'] as String?,
        publishYear = j['publish_year'] as int?,
        edition = j['edition'] as String?,
        noteCount = j['note_count'] as int,
        wordCount = j['word_count'] as int,
        notes = [
          for (final n in (j['notes'] as List? ?? const []))
            Note.fromJson(n as Map<String, dynamic>)
        ];
}
