import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'models.dart';

/// Two interchangeable read-only backends, both serving the shapes in
/// docs/api.md:
///
/// * default — HTTP against the `booknotes serve` API, same-origin (the CLI
///   hosts both the API and this app). Override for `flutter run` dev mode:
///     flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
/// * `--dart-define=STATIC_DATA=true` — the snapshot bundled under
///   assets/data by `booknotes export`. GitHub Pages has no server, so the
///   deployed build uses this.
class Api {
  static const _override = String.fromEnvironment('API_BASE');
  static const _static = bool.fromEnvironment('STATIC_DATA');

  static Uri _endpoint(String path) {
    final base = _override.isNotEmpty ? Uri.parse(_override) : Uri.base;
    return base.replace(path: path, queryParameters: null, fragment: null);
  }

  static Future<Object?> _fetch(String apiPath, String assetPath) async {
    if (_static) {
      return jsonDecode(await rootBundle.loadString(assetPath));
    }
    final res = await http.get(_endpoint(apiPath));
    if (res.statusCode != 200) {
      throw Exception('GET $apiPath returned ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<List<Book>> listBooks() async {
    final data = await _fetch('/api/books', 'assets/data/books.json') as List;
    return [for (final b in data) Book.fromJson(b as Map<String, dynamic>)];
  }

  static Future<Book> getBook(String id) async {
    final data = await _fetch('/api/books/$id', 'assets/data/books/$id.json');
    return Book.fromJson(data as Map<String, dynamic>);
  }
}
