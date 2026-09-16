import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:booknotes/src/db.dart';
import 'package:booknotes/src/repo.dart';
import 'package:booknotes/src/server.dart';
import 'package:sqlite3/sqlite3.dart';

const _jsonEncoder = JsonEncoder.withIndent('  ');

void emitJson(Object? data) => stdout.writeln(_jsonEncoder.convert(data));

String shortId(Object? id) => (id as String).substring(0, 8);

/// Renders rows as aligned columns for human output.
String table(List<String> headers, List<List<String>> rows) {
  final widths = [for (final h in headers) h.length];
  for (final row in rows) {
    for (var i = 0; i < row.length; i++) {
      if (row[i].length > widths[i]) widths[i] = row[i].length;
    }
  }
  String line(List<String> cells) => [
        for (var i = 0; i < cells.length; i++)
          i == cells.length - 1 ? cells[i] : cells[i].padRight(widths[i])
      ].join('  ');
  return [line(headers), for (final r in rows) line(r)].join('\n');
}

abstract class BooknotesCommand extends Command<int> {
  bool get jsonMode => globalResults!.flag('json');

  Database get db {
    final path = resolveDbPath(globalResults!.option('db'));
    return openDb(path);
  }

  /// Prompts y/N on a terminal; without a terminal, requires --yes.
  bool confirm(String prompt, {required bool yes}) {
    if (yes) return true;
    if (!stdin.hasTerminal) {
      throw UsageException(
          'stdin is not a terminal; pass --yes to confirm.', '');
    }
    stdout.write('$prompt [y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    return answer == 'y' || answer == 'yes';
  }
}

/// Resolves a note body from --text, --file, piped stdin, or $EDITOR.
Future<String> readBody(ArgResults args, {String initial = ''}) async {
  final text = args.option('text');
  if (text != null) return text;
  final file = args.option('file');
  if (file != null) {
    final f = File(file);
    if (!f.existsSync()) {
      throw UsageException('File not found: $file', '');
    }
    return f.readAsStringSync();
  }
  if (!stdin.hasTerminal) {
    final bytes = <int>[];
    int b;
    while ((b = stdin.readByteSync()) != -1) {
      bytes.add(b);
    }
    return utf8.decode(bytes);
  }
  final editor = Platform.environment['EDITOR'] ?? 'vi';
  final tmp = File(
      '${Directory.systemTemp.path}/booknotes-${DateTime.now().millisecondsSinceEpoch}.md');
  tmp.writeAsStringSync(initial);
  final process = await Process.start(editor, [tmp.path],
      mode: ProcessStartMode.inheritStdio, runInShell: true);
  final code = await process.exitCode;
  if (code != 0) {
    throw Exception('$editor exited with code $code.');
  }
  final body = tmp.readAsStringSync();
  tmp.deleteSync();
  return body;
}

void printBook(Map<String, Object?> b) {
  stdout.writeln('id:            ${b['id']}');
  stdout.writeln('title:         ${b['title']}');
  stdout.writeln('author:        ${b['author'] ?? '-'}');
  stdout.writeln('publish_year:  ${b['publish_year'] ?? '-'}');
  stdout.writeln('edition:       ${b['edition'] ?? '-'}');
  if (b.containsKey('note_count')) {
    stdout.writeln('notes:         ${b['note_count']}');
    stdout.writeln('words:         ${b['word_count']}');
  }
}

void printNote(Map<String, Object?> n) {
  stdout.writeln('id:        ${n['id']}');
  stdout.writeln('book_id:   ${n['book_id']}');
  stdout.writeln('position:  ${n['position']}');
  stdout.writeln('section:   ${n['section']}');
  stdout.writeln('words:     ${n['word_count']}');
  stdout.writeln('---');
  stdout.writeln(n['body']);
}

// ---------- book commands ----------

class BookCommand extends Command<int> {
  @override
  final name = 'book';
  @override
  final description = 'Manage books.';
  BookCommand() {
    addSubcommand(BookAddCommand());
    addSubcommand(BookListCommand());
    addSubcommand(BookShowCommand());
    addSubcommand(BookUpdateCommand());
    addSubcommand(BookDeleteCommand());
  }
}

class BookAddCommand extends BooknotesCommand {
  @override
  final name = 'add';
  @override
  final description = 'Add a book.';
  BookAddCommand() {
    argParser
      ..addOption('title', mandatory: true, help: 'Book title (required).')
      ..addOption('author', help: 'Author name.')
      ..addOption('year', help: 'Publish year.')
      ..addOption('edition', help: 'Edition, e.g. "2nd ed."');
  }

  @override
  int run() {
    final year = argResults!.option('year');
    final book = createBook(
      db,
      title: argResults!.option('title')!,
      author: argResults!.option('author'),
      publishYear: year == null ? null : int.parse(year),
      edition: argResults!.option('edition'),
    );
    if (jsonMode) {
      emitJson(book);
    } else {
      stdout.writeln('Added book ${shortId(book['id'])}: ${book['title']}');
    }
    return 0;
  }
}

class BookListCommand extends BooknotesCommand {
  @override
  final name = 'list';
  @override
  final description = 'List all books with note and word counts.';

  @override
  int run() {
    final books = listBooks(db);
    if (jsonMode) {
      emitJson(books);
      return 0;
    }
    if (books.isEmpty) {
      stdout.writeln('No books yet. Add one: booknotes book add --title "..."');
      return 0;
    }
    stdout.writeln(table(
      ['ID', 'TITLE', 'AUTHOR', 'YEAR', 'NOTES', 'WORDS'],
      [
        for (final b in books)
          [
            shortId(b['id']),
            b['title'] as String,
            (b['author'] as String?) ?? '-',
            '${b['publish_year'] ?? '-'}',
            '${b['note_count']}',
            '${b['word_count']}',
          ]
      ],
    ));
    return 0;
  }
}

class BookShowCommand extends BooknotesCommand {
  @override
  final name = 'show';
  @override
  final description = 'Show one book and its notes.';
  @override
  final invocation = 'booknotes book show <book-ref>';

  @override
  int run() {
    if (argResults!.rest.length != 1) usageException('Pass one book ref.');
    final d = db;
    final book = resolveBook(d, argResults!.rest.single);
    final id = book['id'] as String;
    final full = {...bookWithCounts(d, id), 'notes': listNotes(d, id)};
    if (jsonMode) {
      emitJson(full);
      return 0;
    }
    printBook(full);
    final notes = full['notes'] as List;
    if (notes.isNotEmpty) {
      stdout.writeln();
      stdout.writeln(table(
        ['POS', 'ID', 'SECTION', 'WORDS'],
        [
          for (final n in notes.cast<Map<String, Object?>>())
            [
              '${n['position']}',
              shortId(n['id']),
              n['section'] as String,
              '${n['word_count']}',
            ]
        ],
      ));
    }
    return 0;
  }
}

class BookUpdateCommand extends BooknotesCommand {
  @override
  final name = 'update';
  @override
  final description =
      'Update book fields. Empty string clears author/edition; --year "" clears year.';
  @override
  final invocation = 'booknotes book update <book-ref> [flags]';
  BookUpdateCommand() {
    argParser
      ..addOption('title')
      ..addOption('author')
      ..addOption('year')
      ..addOption('edition');
  }

  @override
  int run() {
    if (argResults!.rest.length != 1) usageException('Pass one book ref.');
    final d = db;
    final book = resolveBook(d, argResults!.rest.single);
    final year = argResults!.option('year');
    final updated = updateBook(
      d,
      book['id'] as String,
      title: argResults!.option('title'),
      author: argResults!.option('author'),
      publishYear: (year == null || year.isEmpty) ? null : int.parse(year),
      clearYear: year != null && year.isEmpty,
      edition: argResults!.option('edition'),
    );
    if (jsonMode) {
      emitJson(updated);
    } else {
      stdout.writeln('Updated book ${shortId(updated['id'])}.');
      printBook(updated);
    }
    return 0;
  }
}

class BookDeleteCommand extends BooknotesCommand {
  @override
  final name = 'delete';
  @override
  final description = 'Delete a book and all of its notes.';
  @override
  final invocation = 'booknotes book delete <book-ref> [--yes]';
  BookDeleteCommand() {
    argParser.addFlag('yes',
        negatable: false, help: 'Skip the confirmation prompt.');
  }

  @override
  int run() {
    if (argResults!.rest.length != 1) usageException('Pass one book ref.');
    final d = db;
    final book = resolveBook(d, argResults!.rest.single);
    final id = book['id'] as String;
    final counts = bookWithCounts(d, id);
    final ok = confirm(
      'Delete "${book['title']}" and its ${counts['note_count']} notes?',
      yes: argResults!.flag('yes'),
    );
    if (!ok) {
      stdout.writeln('Aborted.');
      return 1;
    }
    deleteBook(d, id);
    if (jsonMode) {
      emitJson({'deleted': id});
    } else {
      stdout.writeln('Deleted book ${shortId(id)}: ${book['title']}');
    }
    return 0;
  }
}

// ---------- note commands ----------

class NoteCommand extends Command<int> {
  @override
  final name = 'note';
  @override
  final description = 'Manage notes.';
  NoteCommand() {
    addSubcommand(NoteAddCommand());
    addSubcommand(NoteListCommand());
    addSubcommand(NoteShowCommand());
    addSubcommand(NoteUpdateCommand());
    addSubcommand(NoteMoveCommand());
    addSubcommand(NoteDeleteCommand());
  }
}

class NoteAddCommand extends BooknotesCommand {
  @override
  final name = 'add';
  @override
  final description =
      'Add a note to a book. Body from --text, --file, piped stdin, or \$EDITOR.';
  @override
  final invocation = 'booknotes note add <book-ref> --section "..." [--text|--file]';
  NoteAddCommand() {
    argParser
      ..addOption('section',
          mandatory: true,
          help: 'The part of the book this note covers, e.g. "ch. 3-5".')
      ..addOption('text', help: 'Note body as an inline argument.')
      ..addOption('file', help: 'Read the note body from a file.');
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.length != 1) usageException('Pass one book ref.');
    final d = db;
    final book = resolveBook(d, argResults!.rest.single);
    final body = await readBody(argResults!);
    if (body.trim().isEmpty) {
      stderr.writeln('Empty note body; nothing added.');
      return 1;
    }
    final note = createNote(
      d,
      bookId: book['id'] as String,
      section: argResults!.option('section')!,
      body: body,
    );
    if (jsonMode) {
      emitJson(note);
    } else {
      stdout.writeln(
          'Added note ${shortId(note['id'])} to "${book['title']}" at position ${note['position']} (${note['word_count']} words).');
    }
    return 0;
  }
}

class NoteListCommand extends BooknotesCommand {
  @override
  final name = 'list';
  @override
  final description = 'List a book\'s notes in order.';
  @override
  final invocation = 'booknotes note list <book-ref>';

  @override
  int run() {
    if (argResults!.rest.length != 1) usageException('Pass one book ref.');
    final d = db;
    final book = resolveBook(d, argResults!.rest.single);
    final notes = listNotes(d, book['id'] as String);
    if (jsonMode) {
      emitJson(notes);
      return 0;
    }
    if (notes.isEmpty) {
      stdout.writeln('No notes for "${book['title']}" yet.');
      return 0;
    }
    stdout.writeln(table(
      ['POS', 'ID', 'SECTION', 'WORDS', 'PREVIEW'],
      [
        for (final n in notes)
          [
            '${n['position']}',
            shortId(n['id']),
            n['section'] as String,
            '${n['word_count']}',
            (n['body'] as String).trim().split('\n').first.length > 40
                ? '${(n['body'] as String).trim().split('\n').first.substring(0, 40)}…'
                : (n['body'] as String).trim().split('\n').first,
          ]
      ],
    ));
    return 0;
  }
}

class NoteShowCommand extends BooknotesCommand {
  @override
  final name = 'show';
  @override
  final description = 'Show one note in full.';
  @override
  final invocation = 'booknotes note show <note-id>';

  @override
  int run() {
    if (argResults!.rest.length != 1) usageException('Pass one note id.');
    final note = resolveNote(db, argResults!.rest.single);
    if (jsonMode) {
      emitJson(note);
    } else {
      printNote(note);
    }
    return 0;
  }
}

class NoteUpdateCommand extends BooknotesCommand {
  @override
  final name = 'update';
  @override
  final description =
      'Update a note\'s section and/or body. --edit opens \$EDITOR pre-filled.';
  @override
  final invocation =
      'booknotes note update <note-id> [--section "..."] [--text|--file|--edit]';
  NoteUpdateCommand() {
    argParser
      ..addOption('section')
      ..addOption('text')
      ..addOption('file')
      ..addFlag('edit',
          negatable: false, help: 'Edit the current body in \$EDITOR.');
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.length != 1) usageException('Pass one note id.');
    final d = db;
    final note = resolveNote(d, argResults!.rest.single);
    String? body;
    if (argResults!.option('text') != null ||
        argResults!.option('file') != null) {
      body = await readBody(argResults!);
    } else if (argResults!.flag('edit')) {
      body = await readBody(argResults!, initial: note['body'] as String);
    }
    final updated = updateNote(
      d,
      note['id'] as String,
      section: argResults!.option('section'),
      body: body,
    );
    if (jsonMode) {
      emitJson(updated);
    } else {
      stdout.writeln(
          'Updated note ${shortId(updated['id'])} (${updated['word_count']} words).');
    }
    return 0;
  }
}

class NoteMoveCommand extends BooknotesCommand {
  @override
  final name = 'move';
  @override
  final description =
      'Move a note to a 1-based position within its book (clamped to range).';
  @override
  final invocation = 'booknotes note move <note-id> <position>';

  @override
  int run() {
    if (argResults!.rest.length != 2) {
      usageException('Pass a note id and a target position.');
    }
    final position = int.tryParse(argResults!.rest[1]);
    if (position == null || position < 1) {
      usageException('Position must be a positive integer.');
    }
    final d = db;
    final note = resolveNote(d, argResults!.rest.first);
    final moved = moveNote(d, note['id'] as String, position);
    if (jsonMode) {
      emitJson(moved);
    } else {
      stdout.writeln(
          'Moved note ${shortId(moved['id'])} to position ${moved['position']}.');
    }
    return 0;
  }
}

class NoteDeleteCommand extends BooknotesCommand {
  @override
  final name = 'delete';
  @override
  final description = 'Delete a note (remaining notes are renumbered).';
  @override
  final invocation = 'booknotes note delete <note-id> [--yes]';
  NoteDeleteCommand() {
    argParser.addFlag('yes',
        negatable: false, help: 'Skip the confirmation prompt.');
  }

  @override
  int run() {
    if (argResults!.rest.length != 1) usageException('Pass one note id.');
    final d = db;
    final note = resolveNote(d, argResults!.rest.single);
    final ok = confirm(
      'Delete note ${shortId(note['id'])} ("${note['section']}", ${note['word_count']} words)?',
      yes: argResults!.flag('yes'),
    );
    if (!ok) {
      stdout.writeln('Aborted.');
      return 1;
    }
    deleteNote(d, note['id'] as String);
    if (jsonMode) {
      emitJson({'deleted': note['id']});
    } else {
      stdout.writeln('Deleted note ${shortId(note['id'])}.');
    }
    return 0;
  }
}

// ---------- serve ----------

class ServeCommand extends BooknotesCommand {
  @override
  final name = 'serve';
  @override
  final description =
      'Serve the read-only JSON API and the built Flutter web UI.';
  ServeCommand() {
    argParser
      ..addOption('port', defaultsTo: '8080')
      ..addOption('web-root',
          help: 'Directory holding the built Flutter web app '
              '(default: app/build/web, searched from the current directory '
              'and one level up).');
  }

  String _defaultWebRoot() {
    for (final candidate in ['app/build/web', '../app/build/web']) {
      if (Directory(candidate).existsSync()) return candidate;
    }
    return 'app/build/web';
  }

  @override
  Future<int> run() async {
    await runServer(
      db,
      port: int.parse(argResults!.option('port')!),
      webRoot: argResults!.option('web-root') ?? _defaultWebRoot(),
    );
    // Keep the process alive until interrupted.
    await ProcessSignal.sigint.watch().first;
    return 0;
  }
}

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
      'booknotes', 'Local book-notes manager backed by SQLite.')
    ..addCommand(BookCommand())
    ..addCommand(NoteCommand())
    ..addCommand(ServeCommand());
  runner.argParser
    ..addOption('db',
        help: 'SQLite database path '
            '(default: \$BOOKNOTES_DB or ~/.booknotes/books.db).')
    ..addFlag('json',
        negatable: false, help: 'Emit machine-readable JSON on stdout.');

  try {
    exitCode = await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 2;
  } on NotFoundException catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  } on AmbiguousException catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 2;
  } catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  }
}
