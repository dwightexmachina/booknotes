import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:sqlite3/sqlite3.dart';

import 'repo.dart';

Response _json(Object? data, {int status = 200}) => Response(
      status,
      body: const JsonEncoder.withIndent('  ').convert(data),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'access-control-allow-origin': '*',
      },
    );

/// Read-only JSON API + static hosting for the built Flutter web app.
Future<void> runServer(
  Database db, {
  required int port,
  required String webRoot,
}) async {
  final router = Router();

  router.get('/api/health', (Request _) => _json({'ok': true}));

  router.get('/api/books', (Request _) => _json(listBooks(db)));

  router.get('/api/books/<id>', (Request req, String id) {
    try {
      final book = resolveBook(db, id);
      final bookId = book['id'] as String;
      return _json({
        ...bookWithCounts(db, bookId),
        'notes': listNotes(db, bookId),
      });
    } on NotFoundException catch (e) {
      return _json({'error': e.message}, status: 404);
    } on AmbiguousException catch (e) {
      return _json({'error': e.message}, status: 400);
    }
  });

  final hasWebRoot = Directory(webRoot).existsSync();
  final static_ = hasWebRoot
      ? createStaticHandler(webRoot, defaultDocument: 'index.html')
      : (Request _) => Response.ok(
            'booknotes API is running, but no web build was found at '
            '"$webRoot".\nBuild the UI with: cd app && flutter build web\n'
            'API: /api/books, /api/books/<id>\n',
            headers: {'content-type': 'text/plain; charset=utf-8'},
          );

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(Cascade().add(router.call).add(static_).handler);

  final server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
  stdout.writeln('booknotes serving on http://localhost:${server.port}');
  stdout.writeln(hasWebRoot
      ? 'Web UI: http://localhost:${server.port}  (from $webRoot)'
      : 'No web build found at $webRoot — API only.');
}
