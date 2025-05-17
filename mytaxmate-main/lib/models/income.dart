class Income {
  final String id;
  final String date;
  final String source; // e.g., Employer Name, Client Name, Investment Platform
  final String type; // e.g., Salary, Freelance, Dividends, Rental
  final double amount;
  final String userId;
  final DateTime createdAt;
  final String? documentStoragePath; // For payslips, invoices, etc.

  Income({
    required this.id,
    required this.date,
    required this.source,
    required this.type,
    required this.amount,
    required this.userId,
    required this.createdAt,
    this.documentStoragePath,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] as String,
      date: json['date'] as String,
      source: json['source'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      userId: json['user_id'] as String,
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
