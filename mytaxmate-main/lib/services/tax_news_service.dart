import '../models/tax_news_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaxNewsService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<TaxNewsItem>> fetchTaxNews() async {
    try {
      // Fetch real data from the 'tax_news' table
      final response = await _client
          .from('tax_news')
          .select()
          .order('published_date', ascending: false)
          .limit(20);

      if (response.isEmpty) {
        return [];
      }

      final List<dynamic> data = response;
      return data.map((json) => TaxNewsItem.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching tax news: $e');
      throw Exception('Failed to load tax news. Please try again later.');
    }
  }
}
