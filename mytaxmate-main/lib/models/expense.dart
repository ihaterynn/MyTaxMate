class Expense {
  final String id;
  final String date;
  final String merchant;
  final String category;
  final double amount;
  final bool isDeductible;
  final String userId;
  final DateTime createdAt;
  final String? receiptStoragePath;

  Expense({
    required this.id,
    required this.date,
    required this.merchant,
    required this.category,
    required this.amount,
    required this.isDeductible,
    required this.userId,
    required this.createdAt,
    this.receiptStoragePath,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      date: json['date'] as String,
      merchant: json['merchant'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      isDeductible: json['is_deductible'] as bool,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      receiptStoragePath: json['receipt_storage_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'merchant': merchant,
    'category': category,
    'amount': amount,
    'is_deductible': isDeductible,
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
    'receipt_storage_path': receiptStoragePath,
  };
}
