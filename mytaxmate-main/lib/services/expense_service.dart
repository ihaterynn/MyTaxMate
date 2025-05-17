import 'package:supabase_flutter/supabase_flutter.dart';
// Assuming your Expense model is in a file named 'expense.dart'
// in a directory called 'models' relative to this file.
// Adjust the import path if your file structure is different.
import '../models/expense.dart'; // Make sure this path is correct

class ExpenseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches the 10 most recent expenses.
  ///
  /// Throws an error if the Supabase query fails.
  Future<List<Expense>> getRecentExpenses() async {
    try {
      // Execute the query to get the response
      final response = await _supabase
          .from('expenses') // Specifies the table 'expenses'
          .select() // Selects all columns, or specify columns like: .select('id, name, amount, created_at')
          .order('created_at', ascending: false) // Orders by 'created_at' in descending order
          .limit(10); // Limits the result to 10 records

      // Map the list of JSON objects to a list of Expense objects.
      // If the response is an empty list, this will correctly return an empty list of Expenses.
      return (response).map((json) => Expense.fromJson(json as Map<String, dynamic>)).toList();
        } catch (error) {
      // Log the error or handle it as per your application's error handling strategy.
      print('Error fetching recent expenses: $error');
      // Re-throw the error if you want calling code to also handle it.
      rethrow;
    }
  }
}