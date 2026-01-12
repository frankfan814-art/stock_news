import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_item.dart';

class ApiService {
  // 生产环境使用服务器地址
  static const String baseUrl = 'http://124.222.203.221';
  static const Duration timeout = Duration(seconds: 60);

  /// 健康检查
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 触发新闻抓取
  static Future<Map<String, dynamic>> crawlNews({
    String? date,
    List<String>? keywords,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (date != null) body['date'] = date;
      if (keywords != null && keywords.isNotEmpty) {
        body['keywords'] = keywords;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/crawl'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('抓取失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('抓取失败: $e');
    }
  }

  /// 获取新闻列表
  static Future<List<NewsItem>> getNews({
    String? date,
    String? keywords,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;
      if (keywords != null) queryParams['keywords'] = keywords;

      final uri = Uri.parse('$baseUrl/news')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body) as List;
        return jsonList.map((json) => NewsItem.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('获取新闻失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取新闻失败: $e');
    }
  }

  /// 获取上次更新时间
  static Future<DateTime?> getLastUpdate() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/last-update'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lastUpdate = data['last_update'] as String?;
        return lastUpdate != null ? DateTime.parse(lastUpdate) : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
