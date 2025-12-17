import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/news_item.dart';

class NewsService {
  static const _apiBase = 'https://finnhub.io/api/v1';
  static final _token = const String.fromEnvironment('FINNHUB_TOKEN');

  static Future<NewsItem?> fetchHighlight() async {
    if (_token.isEmpty) return null;

    final uri = Uri.parse('$_apiBase/news?category=general&token=$_token');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('뉴스 HTTP ${res.statusCode}');
    }

    final raw = jsonDecode(res.body);
    if (raw is! List) return null;
    if (raw.isEmpty) return null;

    final items = raw
        .whereType<Map<String, dynamic>>()
        .map(NewsItem.fromJson)
        .toList();

    if (items.isEmpty) return null;

    // 오늘 기사 우선(없으면 최신)
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    final today = items.where((e) => isToday(e.datetime)).toList();
    return today.isNotEmpty ? today.first : items.first;
  }
}
