import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app's data comes from. The real one reads the website's feeds;
/// tests hand in a fake with fixed JSON (like passing a stub in Python).
abstract class FeedSource {
  /// The feed called [name] ('matchday', 'tournaments', 'analysis') as decoded JSON.
  Future<Map<String, dynamic>> load(String name);
}

/// Reads `https://rugbyanalysis.com/app/<name>.json`, which the daily pipeline
/// rebuilds every morning. The last good copy is kept on the phone, so the app
/// still opens with no signal, and a failed download falls back to it.
class WebFeedSource implements FeedSource {
  WebFeedSource({this.base = 'https://rugbyanalysis.com/app/', http.Client? client}) : _client = client ?? http.Client();

  final String base;
  final http.Client _client;

  @override
  Future<Map<String, dynamic>> load(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'feed:$name';
    try {
      final res = await _client.get(Uri.parse('$base$name.json')).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}');
      final text = utf8.decode(res.bodyBytes);
      final json = jsonDecode(text) as Map<String, dynamic>;
      await prefs.setString(cacheKey, text);
      return json;
    } catch (e) {
      final cached = prefs.getString(cacheKey);
      if (cached == null) rethrow;
      debugPrint('Using the saved $name feed: $e');
      return jsonDecode(cached) as Map<String, dynamic>;
    }
  }
}
