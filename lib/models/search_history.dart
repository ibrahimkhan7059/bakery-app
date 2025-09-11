class SearchHistory {
  final String query;
  final DateTime timestamp;

  SearchHistory({
    required this.query,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SearchHistory.fromJson(Map<String, dynamic> json) => SearchHistory(
        query: json['query'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}
