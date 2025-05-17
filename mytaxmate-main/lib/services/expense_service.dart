import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart'; // Make sure this path is correct

class ExpenseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches the 10 most recent expenses.
  Future<List<Expense>> getRecentExpenses() async {
    try {
      final response = await _supabase
          .from('expenses')
          .select() 
          .order('created_at', ascending: false)
          .limit(10);

      return (response).map((json) => Expense.fromJson(json)).toList();
    } catch (error) {
      print('Error fetching recent expenses: $error');
      rethrow;
    }
  }

  /// Fetches recent expenses and returns them as a list of maps (JSON encodable).
  /// Fetches up to 20 most recent expenses for more comprehensive analysis by the AI.
  Future<List<Map<String, dynamic>>> getRecentExpensesAsJsonEncodable({int limit = 20}) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select('date, merchant, category, amount, is_deductible') // Select specific fields AI might need
          .order('created_at', ascending: false)
          .limit(limit);

      // The response is already a List<Map<String, dynamic>>
      // No need to map to Expense objects if we just need the JSON structure
      // However, if you want to ensure data types or structure via the Expense model first:
      // return response.map((json) => Expense.fromJson(json).toJsonForAI()).toList();
      // For simplicity, if the direct Supabase response structure is fine:
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching recent expenses for AI: $error');
      rethrow;
    }
  }
}

// You might want to add a toJsonForAI method in your Expense model if you need specific formatting
// or want to exclude certain fields before sending to the AI.
// For example, in models/expense.dart:
/*
  Map<String, dynamic> toJsonForAI() => {
    'date': date,
    'merchant': merchant,
    'category': category,
    'amount': amount,
    'is_deductible': isDeductible,
    // 'user_id': userId, // Maybe exclude user_id for privacy/relevance to AI
    // 'created_at': createdAt.toIso8601String(), // AI might not need this precise timestamp
  };
*/