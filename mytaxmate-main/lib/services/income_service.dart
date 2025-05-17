import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/income.dart'; // Make sure this path is correct

class IncomeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches the 10 most recent income records.
  Future<List<Income>> getRecentIncomes() async {
    try {
      final response = await _supabase
          .from('incomes') // Specifies the table 'incomes'
          .select() 
          .order('created_at', ascending: false) 
          .limit(10); 

      return (response).map((json) => Income.fromJson(json)).toList();
    } catch (error) {
      print('Error fetching recent incomes: $error');
      rethrow;
    }
  }

  /// Adds a new income record to the Supabase table.
  Future<void> addIncome(Map<String, dynamic> incomeData) async {
    try {
      await _supabase.from('incomes').insert(incomeData);
    } catch (error) {
      print('Error adding income: $error');
      rethrow;
    }
  }
}
