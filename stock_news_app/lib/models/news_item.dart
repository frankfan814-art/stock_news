class NewsItem {
  final String source;
  final String title;
  final String summary;
  final String url;
  final DateTime publishedAt;
  final DateTime fetchedAt;

  NewsItem({
    required this.source,
    required this.title,
    required this.summary,
    required this.url,
    required this.publishedAt,
    required this.fetchedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      source: json['source'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      url: json['url'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'title': title,
      'summary': summary,
      'url': url,
      'published_at': publishedAt.toIso8601String(),
      'fetched_at': fetchedAt.toIso8601String(),
    };
  }
}
