import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Same-origin by default (the CLI's `serve` hosts both the API and this app).
/// Override for `flutter run` dev mode with:
///   flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
class Api {
  static const _override = String.fromEnvironment('API_BASE');

  static Uri _endpoint(String path) {
    final base = _override.isNotEmpty ? Uri.parse(_override) : Uri.base;
    return base.replace(path: path, queryParameters: null, fragment: null);
  }

  static Future<List<Book>> listBooks() async {
    final res = await http.get(_endpoint('/api/books'));
    if (res.statusCode != 200) {
      throw Exception('GET /api/books returned ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return [for (final b in data) Book.fromJson(b as Map<String, dynamic>)];
  }

  static Future<Book> getBook(String id) async {
    final res = await http.get(_endpoint('/api/books/$id'));
    if (res.statusCode != 200) {
      throw Exception('GET /api/books/$id returned ${res.statusCode}');
    }
    return Book.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }
}
