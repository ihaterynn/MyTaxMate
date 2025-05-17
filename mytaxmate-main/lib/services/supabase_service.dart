import 'dart:io'; // Required for File type
import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p; // For getting file extension

class SupabaseService {
  Future<void> initialize() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  SupabaseClient get client => Supabase.instance.client;

  // Method to upload a file to Supabase Storage
  Future<String> uploadFileToStorage(File file, String bucketName) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      final filePathInBucket = '${user.id}/$fileName';

      await client.storage
          .from(bucketName)
          .upload(
            filePathInBucket,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      // Return the public URL or just the path. For simplicity, returning path.
      // final publicUrl = client.storage.from(bucketName).getPublicUrl(filePathInBucket);
      // return publicUrl;
      return filePathInBucket; // Store this path in your database
    } catch (e) {
      print('Error uploading file to Supabase Storage: $e');
      rethrow; // Rethrow to handle it in the UI
    }
  }

  // Method to add a receipt record to the 'receipts' table
  Future<void> addReceiptRecord(Map<String, dynamic> receiptData) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }
      // Ensure user_id is part of receiptData or add it here
      receiptData['user_id'] = user.id;

      await client.from('receipts').insert(receiptData);
    } catch (e) {
      print('Error adding receipt record to Supabase: $e');
      rethrow; // Rethrow to handle it in the UI
    }
  }

  // Method to add an expense record to the 'expenses' table
  Future<void> addExpense(Map<String, dynamic> expenseData) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }
      // Ensure user_id is part of expenseData or add it here
      // The expenseData map from the form should already include user_id and created_at
      // but this is a good safeguard if creating expenseData elsewhere.
      if (!expenseData.containsKey('user_id')) {
        expenseData['user_id'] = user.id;
      }
      if (!expenseData.containsKey('created_at')) {
        expenseData['created_at'] = DateTime.now().toIso8601String();
      }
      // If your 'expenses' table has an 'id' column that is not auto-generated
      // by the database (e.g., if you are using client-side UUIDs),
      // ensure it's included in expenseData before this call.
      // Example: if (!expenseData.containsKey('id')) { expenseData['id'] = Uuid().v4(); }

      await client.from('expenses').insert(expenseData);
    } catch (e) {
      print('Error adding expense record to Supabase: $e');
      rethrow; // Rethrow to handle it in the UI
    }
  }

  // Method to upload file bytes (for Web) to Supabase Storage
  Future<String> uploadFileBytesToStorage(
    Uint8List fileBytes,
    String fileName,
    String bucketName,
  ) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }
      // Use the provided fileName, ensure it has an extension for Supabase to infer mime type
      // Or, explicitly set mime type in FileOptions if needed.
      final uniqueFileName =
          '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final filePathInBucket = '${user.id}/$uniqueFileName';

      await client.storage
          .from(bucketName)
          .uploadBinary(
            filePathInBucket,
            fileBytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: _getMimeType(fileName),
            ),
          );
      return filePathInBucket;
    } catch (e) {
      print('Error uploading file bytes to Supabase Storage: $e');
      rethrow;
    }
  }

  // Helper to get mime type from file name, can be expanded
  String? _getMimeType(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    if (extension == '.pdf') return 'application/pdf';
    if (extension == '.jpg' || extension == '.jpeg') return 'image/jpeg';
    if (extension == '.png') return 'image/png';
    return null; // Let Supabase attempt to infer or default
  }
}
