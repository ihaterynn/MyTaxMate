class TaxNewsItem {
  final String
  id; // Could be a unique ID from your DB or the URL itself if unique
  final String title;
  final String url;
  final String? summary; // Optional summary
  final DateTime? publishedDate; // Optional, if available from scrape
  final DateTime fetchedAt; // When your backend fetched it

  TaxNewsItem({
    required this.id,
    required this.title,
    required this.url,
    this.summary,
    this.publishedDate,
    required this.fetchedAt,
  });

  // Factory constructor to create from JSON (matching your backend/DB output)
  factory TaxNewsItem.fromJson(Map<String, dynamic> json) {
    return TaxNewsItem(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      summary: json['summary'] as String?,
      publishedDate:
          json['published_date'] != null
              ? DateTime.tryParse(json['published_date'] as String)
              : null,
      fetchedAt: DateTime.parse(
        json['fetched_at'] as String,
      ), // Assuming this is always present
    );
  }

  // toJson if you ever need to send this model (less common for display models)
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'summary': summary,
    'published_date': publishedDate?.toIso8601String(),
    'fetched_at': fetchedAt.toIso8601String(),
  };
}
