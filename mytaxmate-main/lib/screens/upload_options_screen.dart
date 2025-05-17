import 'dart:io';
import 'dart:async'; // <-- Add this line
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mytaxmate/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http; 
import 'dart:convert'; 

class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

 // TODO: Replace with your actual backend API URL
  final String _receiptProcessingApiUrl = 'http://localhost:8001/process-receipt'; // Remove trailing slash
  final _dateController = TextEditingController();
  final _merchantController = TextEditingController();
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isDeductible = false;
  bool _isSubmitting = false;
  bool _isAiProcessing = false; 

  // For non-web, store File. For web, store bytes and name.
  File? _selectedReceiptFile;
  Uint8List? _selectedReceiptFileBytes;
  String? _selectedReceiptFileName; 

  @override
  void dispose() {
    _dateController.dispose();
    _merchantController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _dateController.text.isNotEmpty
              ? (DateFormat('yyyy-MM-dd').parse(_dateController.text) ??
                  DateTime.now())
              : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickReceiptFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: kIsWeb,
    );

    if (result != null) {
      setState(() { // Ensure UI updates after picking
        if (kIsWeb) {
          _selectedReceiptFileBytes = result.files.single.bytes;
          _selectedReceiptFileName = result.files.single.name;
          _selectedReceiptFile = null; 
        } else {
          final path = result.files.single.path;
          if (path != null) {
            _selectedReceiptFile = File(path);
            _selectedReceiptFileName = p.basename(path); // Get filename for non-web too
            _selectedReceiptFileBytes = null; 
          } else {
            _clearSelectedFile();
          }
        }
      });
    } else {
    
    }
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedReceiptFile = null;
      _selectedReceiptFileBytes = null;
      _selectedReceiptFileName = null;
    });
  }

  Future<void> _submitExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      String? receiptStoragePath;

      try {
        // First, handle the primary selected receipt file for storage
        if (_selectedReceiptFileBytes != null && _selectedReceiptFileName != null && kIsWeb) {
          // Web: Upload bytes from primary selection
          receiptStoragePath = await _supabaseService.uploadFileBytesToStorage(
            _selectedReceiptFileBytes!,
            _selectedReceiptFileName!,
            'receipts-bucket',
          );
          print('Uploaded primary receipt (web) to: $receiptStoragePath');
        } else if (_selectedReceiptFile != null && !kIsWeb) {
          // Non-web: Upload file from primary selection
          receiptStoragePath = await _supabaseService.uploadFileToStorage(
            _selectedReceiptFile!,
            'receipts-bucket',
          );
          print('Uploaded primary receipt to: $receiptStoragePath');
        }

        final userId = _supabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated.');
        }

        final expenseData = {
          'date': _dateController.text,
          'merchant': _merchantController.text,
          'category': _categoryController.text,
          'amount': double.tryParse(_amountController.text) ?? 0.0,
          'is_deductible': _isDeductible,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
          if (receiptStoragePath != null)
            'receipt_storage_path': receiptStoragePath,
        };

        await _supabaseService.addExpense(expenseData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully!')),
          );
          _clearSelectedFile(); // Clear selection after successful submit
          _formKey.currentState?.reset(); // Reset form fields
          _dateController.clear();
          _merchantController.clear();
          _categoryController.clear();
          _amountController.clear();
          setState(() {
            _isDeductible = false;
          });
          // Consider Navigator.pop(context); if you want to go back
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add expense: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  // Renamed and updated function for AI generation
  Future<void> _aiGenerateAndFillForm() async {
    // This function now uses the already selected file
    if (_selectedReceiptFileBytes == null && _selectedReceiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a receipt file first.')),
      );
      return;
    }

    setState(() {
      _isAiProcessing = true;
    });

    // Use _selectedReceiptFileBytes (web) or read from _selectedReceiptFile (non-web)
    Uint8List? imageBytes = _selectedReceiptFileBytes;
    if (!kIsWeb && _selectedReceiptFile != null) {
      imageBytes = await _selectedReceiptFile!.readAsBytes();
    }
    
    // We already have _selectedReceiptFileName from the _pickReceiptFile method

    if (imageBytes != null && _selectedReceiptFileName != null) {
      try {
        // Ensure the URL does NOT have a trailing slash to match the FastAPI endpoint
        final apiUrl = _receiptProcessingApiUrl.endsWith('/')
            ? _receiptProcessingApiUrl.substring(0, _receiptProcessingApiUrl.length - 1)
            : _receiptProcessingApiUrl;
            
        var request = http.MultipartRequest('POST', Uri.parse(apiUrl)); // apiUrl should not have trailing slash
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: _selectedReceiptFileName!,
        ));
        
        // You can add other fields if your backend expects them, e.g.:
        // request.fields['user_id'] = _supabaseService.client.auth.currentUser?.id ?? 'unknown';

        final client = http.Client();
        try {
          // Send the request and follow redirects manually if needed
          // Add a timeout to the request
          final streamedResponse = await client.send(request).timeout(const Duration(seconds: 30), // Example: 30 seconds timeout
              onTimeout: () {
            // This callback is executed if the timeout occurs.
            // It should return a http.StreamedResponse or throw an error.
            // For simplicity, we'll throw a TimeoutException which will be caught by the catch block.
            throw TimeoutException('The connection has timed out, Please try again!');
          });
          
          final response = await http.Response.fromStream(streamedResponse);
          
          if (response.statusCode == 200) {
            final extractedData = jsonDecode(response.body);
            
            // Assuming the backend returns data in a structure like:
            // {
            //   'date': 'YYYY-MM-DD',
            //   'merchant': 'Merchant Name',
            //   'amount': 123.45,
            //   'category': 'Suggested Category',
            //   'is_deductible': true/false 
            // }
            // Adjust the keys below based on your actual backend response.

            setState(() {
              _dateController.text = extractedData['date']?.toString() ?? '';
              _merchantController.text = extractedData['merchant']?.toString() ?? '';
              _amountController.text = (extractedData['amount'] as num?)?.toString() ?? '';
              _categoryController.text = extractedData['category']?.toString() ?? '';
              _isDeductible = (extractedData['is_deductible'] as bool?) ?? false;

              // If the AI-suggested category is not in the standard list, add it for selection
              if (_categoryController.text.isNotEmpty && !standardCategories.contains(_categoryController.text)) {
                  // This logic might need to be adjusted based on how `standardCategories` is accessed here.
                  // For simplicity, assuming `standardCategories` is accessible or managed in a way that allows this.
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fields auto-filled by AI. Please review.')),
              );
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('AI processing failed: ${response.statusCode} - ${response.body}')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error calling AI service: ${e.toString()}')),
          );
        } finally {
          client.close();
        }
        
        // The following block was duplicated and has been removed:
        // final streamedResponse = await request.send().timeout(const Duration(seconds: 30), ...
        // ... down to the end of its corresponding try-catch block.

      } catch (e) { // This catch is for the outer try block (e.g., if URI parsing fails)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing AI request: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not process the selected file for AI generation.')),
      );
    }

    setState(() {
      _isAiProcessing = false;
    });
  }


  // Define standardCategories here or pass it appropriately if it's defined elsewhere
  // For this example, I'll define it within the state class for simplicity,
  // but it might be better as a static const or part of a configuration.
  final List<String> standardCategories = ['Food', 'Transport', 'Utilities', 'Office Supplies', 'Software', 'Travel', 'Other'];


  @override
  Widget build(BuildContext context) {
    // Create a mutable list for dropdown items
    List<String> dropdownCategories = List.from(standardCategories);

    // If the controller has a value and it's not in the standard list, add it
    if (_categoryController.text.isNotEmpty && !dropdownCategories.contains(_categoryController.text)) {
      dropdownCategories.add(_categoryController.text);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Expense'), elevation: 1),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // Single Upload Button
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Receipt/Invoice'),
                onPressed: _isAiProcessing || _isSubmitting ? null : _pickReceiptFile,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),

              // Display selected file name
              if (_selectedReceiptFileName != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'File: $_selectedReceiptFileName',
                          style: TextStyle(color: Colors.green[700], fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.redAccent[400], size: 18),
                        onPressed: _clearSelectedFile,
                        tooltip: 'Clear selected file',
                      )
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // AI Auto-Fill Button - Enabled only if a file is selected
              ElevatedButton.icon(
                icon: _isAiProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_outlined), // Changed icon
                label: Text(_isAiProcessing ? 'Processing...' : 'AI Auto-Fill Form from Receipt'),
                onPressed: (_selectedReceiptFileBytes == null && _selectedReceiptFile == null) || _isAiProcessing || _isSubmitting
                    ? null // Disabled if no file or already processing/submitting
                    : _aiGenerateAndFillForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, // Or your theme's secondary color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24), // Space before form fields

              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  hintText: 'Select expense date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a date';
                  }
                  try {
                    DateFormat('yyyy-MM-dd').parseStrict(value);
                  } catch (e) {
                    return 'Invalid date format (YYYY-MM-DD expected)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant',
                  hintText: 'Enter merchant name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter merchant name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter expense amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                value: _categoryController.text.isEmpty ? null : _categoryController.text,
                hint: const Text('Select or type category'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select or enter a category';
                  }
                  return null;
                },
                items: dropdownCategories // Use the dynamic list here
                    .map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _categoryController.text = newValue ?? '';
                    // Optional: If you want the dynamic list to shrink if an AI-added item is unselected,
                    // you might add logic here to remove it from dropdownCategories if it's not in standardCategories.
                    // However, for simplicity, this keeps it in the list for the current session.
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Is this tax deductible?'),
                value: _isDeductible,
                onChanged: (bool value) {
                  setState(() {
                    _isDeductible = value;
                  });
                },
                secondary: Icon(
                  _isDeductible ? Icons.check_circle_outline : Icons.highlight_off_outlined,
                  color: _isDeductible ? Colors.green : Colors.grey,
                ),
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.green,
              ),
              const SizedBox(height: 24),
              // Removed the "Selected Receipt" text and "Change/Attach Receipt" buttons here
              // as the upload and display are now handled at the top.

              if (_isSubmitting) // Show loading indicator near submit button if submitting
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8.0),
                   child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))),
                 )
              else if (_isAiProcessing) // Also show loading indicator near submit button if AI is processing
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8.0),
                   child: Center(child: Text("AI is processing...", style: TextStyle(color: Theme.of(context).primaryColor))),
                 ),
              ElevatedButton(
                onPressed: (_isSubmitting || _isAiProcessing) ? null : _submitExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
