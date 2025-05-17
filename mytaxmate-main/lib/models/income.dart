class Income {
  final String id;
  final String date;
  final String source;
  final String type;
  final double amount;
  final String userId;
  final DateTime createdAt;
  final String? documentStoragePath;

  Income({
    required this.id,
    required this.userId,
    required this.date,
    required this.source,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.documentStoragePath,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: json['date'] as String,
      source: json['source'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      documentStoragePath: json['document_storage_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'source': source,
    'type': type,
    'amount': amount,
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
    'document_storage_path': documentStoragePath,
  };
}
