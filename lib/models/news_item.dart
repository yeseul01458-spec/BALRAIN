class NewsItem {
  final String headline;
  final String source;
  final String url;
  final String? imageUrl;
  final DateTime datetime;
  final List<String> related;

  const NewsItem({
    required this.headline,
    required this.source,
    required this.url,
    required this.datetime,
    this.imageUrl,
    this.related = const [],
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) {
    final rel = (j['related'] ?? '').toString().trim();
    final related = rel.isEmpty
        ? <String>[]
        : rel
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final unix = (j['datetime'] is num) ? (j['datetime'] as num).toInt() : 0;

    final imageRaw = (j['image'] ?? '').toString().trim();
    final imageUrl = imageRaw.isEmpty ? null : imageRaw;

    return NewsItem(
      headline: (j['headline'] ?? '').toString(),
      source: (j['source'] ?? '').toString(),
      url: (j['url'] ?? '').toString(),
      imageUrl: imageUrl,
      datetime:
      DateTime.fromMillisecondsSinceEpoch(unix * 1000, isUtc: true).toLocal(),
      related: related,
    );
  }
}
