import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';

void main() => runApp(const BooknotesApp());

String fmtNum(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class BooknotesApp extends StatelessWidget {
  const BooknotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData themed(Palette p, Brightness b) => ThemeData(
          brightness: b,
          scaffoldBackgroundColor: p.paper,
          colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: b),
          splashFactory: NoSplash.splashFactory,
        );
    return MaterialApp(
      title: 'booknotes',
      debugShowCheckedModeBanner: false,
      theme: themed(Palette.light, Brightness.light),
      darkTheme: themed(Palette.dark, Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Book>? books;
  Book? detail;
  String? selectedId;
  String? error;
  bool loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => error = null);
    try {
      final result = await Api.listBooks();
      setState(() => books = result);
      if (result.isNotEmpty &&
          (selectedId == null || !result.any((b) => b.id == selectedId))) {
        _select(result.first.id);
      } else if (selectedId != null) {
        _select(selectedId!);
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _select(String id) async {
    setState(() {
      selectedId = id;
      loadingDetail = true;
    });
    try {
      final b = await Api.getBook(id);
      if (b.id == selectedId) {
        setState(() {
          detail = b;
          loadingDetail = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loadingDetail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (error != null) return _ErrorView(message: error!, onRetry: _loadBooks);
    if (books == null) {
      return Scaffold(
          body: Center(child: CircularProgressIndicator(color: p.accent)));
    }
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 340,
            child: _Sidebar(
              books: books!,
              selectedId: selectedId,
              onSelect: _select,
              onRefresh: _loadBooks,
            ),
          ),
          Container(width: 1, color: p.hairline),
          Expanded(
            child: books!.isEmpty
                ? const _EmptyLibrary()
                : loadingDetail && detail == null
                    ? Center(child: CircularProgressIndicator(color: p.accent))
                    : detail == null
                        ? const SizedBox.shrink()
                        : _DetailPane(book: detail!),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<Book> books;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onRefresh;

  const _Sidebar({
    required this.books,
    required this.selectedId,
    required this.onSelect,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final totalWords = books.fold(0, (s, b) => s + b.wordCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.hairline)),
          ),
          child: Row(
            children: [
              Text('booknotes',
                  style: TextStyle(
                    fontFamily: serif,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  )),
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: p.accent, shape: BoxShape.circle),
              ),
              const Spacer(),
              Text(
                '${books.length} books · ${fmtNum(totalWords)} words',
                style: TextStyle(
                    fontSize: 12, color: p.muted, fontFamily: mono),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: Icon(Icons.refresh, size: 16, color: p.faint),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: [
              for (final b in books)
                _BookRow(
                  book: b,
                  selected: b.id == selectedId,
                  onTap: () => onSelect(b.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookRow extends StatelessWidget {
  final Book book;
  final bool selected;
  final VoidCallback onTap;

  const _BookRow(
      {required this.book, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Material(
      color: selected ? p.rowSelected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: p.rowHover,
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 12, 20, 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? p.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.title,
                  style: TextStyle(
                    fontFamily: serif,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: p.ink,
                  )),
              const SizedBox(height: 2),
              Text(
                [
                  if (book.author != null) book.author!,
                  if (book.publishYear != null) '${book.publishYear}',
                ].join(' · '),
                style: TextStyle(fontSize: 12.5, color: p.muted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _countChip(p, '${book.noteCount}', 'notes'),
                  const SizedBox(width: 14),
                  _countChip(p, fmtNum(book.wordCount), 'words'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countChip(Palette p, String num, String label) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: num,
            style: TextStyle(
                color: selected ? p.accent : p.ink,
                fontWeight: FontWeight.w500)),
        TextSpan(text: ' $label'),
      ]),
      style: TextStyle(fontFamily: mono, fontSize: 11.5, color: p.faint),
    );
  }
}

class _DetailPane extends StatelessWidget {
  final Book book;

  const _DetailPane({required this.book});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      color: p.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(44, 36, 44, 64),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(p),
                for (var i = 0; i < book.notes.length; i++)
                  _NoteView(
                    note: book.notes[i],
                    isLast: i == book.notes.length - 1,
                  ),
                _footer(p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(Palette p) {
    final byline = [
      if (book.author != null) book.author!,
      if (book.publishYear != null) '${book.publishYear}',
      if (book.edition != null) book.edition!,
    ].join('  ·  ');
    return Container(
      padding: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(book.title,
              style: TextStyle(
                fontFamily: serif,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: p.ink,
              )),
          const SizedBox(height: 6),
          Text(byline, style: TextStyle(fontSize: 14.5, color: p.muted)),
          const SizedBox(height: 10),
          SelectableText('uuid ${book.id}',
              style: TextStyle(fontFamily: mono, fontSize: 11, color: p.faint)),
          const SizedBox(height: 18),
          Row(
            children: [
              _stat(p, '${book.noteCount}', 'NOTES'),
              const SizedBox(width: 36),
              _stat(p, fmtNum(book.wordCount), 'TOTAL WORDS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(Palette p, String num, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(num,
            style: TextStyle(
              fontFamily: mono,
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: p.accent,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.9,
              color: p.muted,
            )),
      ],
    );
  }

  Widget _footer(Palette p) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.hairline)),
      ),
      child: Text(
        'Read-only viewer — add or edit notes with the CLI: '
        'booknotes note add "${book.title}" --section "..."',
        style: TextStyle(fontSize: 12, color: p.faint),
      ),
    );
  }
}

class _NoteView extends StatelessWidget {
  final Note note;
  final bool isLast;

  const _NoteView({required this.note, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                note.position.toString().padLeft(2, '0'),
                style:
                    TextStyle(fontFamily: mono, fontSize: 12, color: p.faint),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.chipBg,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(note.section,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: p.chipInk,
                          )),
                    ),
                    const SizedBox(width: 10),
                    Text('${fmtNum(note.wordCount)} words',
                        style: TextStyle(
                            fontFamily: mono, fontSize: 11.5, color: p.faint)),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  note.body.trim(),
                  style: TextStyle(
                    fontFamily: serif,
                    fontSize: 16,
                    height: 1.65,
                    color: p.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      color: p.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No books yet',
              style: TextStyle(
                  fontFamily: serif,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: p.ink)),
          const SizedBox(height: 8),
          Text('Add one from the terminal:',
              style: TextStyle(fontSize: 13, color: p.muted)),
          const SizedBox(height: 6),
          Text('booknotes book add --title "..." --author "..."',
              style:
                  TextStyle(fontFamily: mono, fontSize: 12.5, color: p.accent)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Can\'t reach the booknotes API',
                style: TextStyle(
                    fontFamily: serif,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: p.ink)),
            const SizedBox(height: 8),
            Text('Is `booknotes serve` running?',
                style: TextStyle(fontSize: 13, color: p.muted)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: mono, fontSize: 11, color: p.faint)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.accent,
                side: BorderSide(color: p.accent),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
