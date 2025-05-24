import 'dart:convert'; // For jsonEncode
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mytaxmate/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:async'; // Import for TimeoutException

class IncomeEntryScreen extends StatefulWidget {
  const IncomeEntryScreen({super.key});

  @override
  State<IncomeEntryScreen> createState() => _IncomeEntryScreenState();
}

class _IncomeEntryScreenState extends State<IncomeEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  final _dateController = TextEditingController();
  final _sourceController = TextEditingController(); // e.g., Employer, Client
  final _typeController = TextEditingController(); // e.g., Salary, Freelance
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController(); // New controller for description
  final _docRefController = TextEditingController(); // New controller for document reference
  bool _isSubmitting = false;
  bool _isAiProcessing = false; // New state for AI processing

  // For file handling (similar to ExpenseEntryScreen)
  File? _selectedDocumentFile;
  Uint8List? _selectedDocumentFileBytes;
  String? _selectedDocumentFileName;

  @override
  void dispose() {
    _dateController.dispose();
    _sourceController.dispose();
    _typeController.dispose();
    _amountController.dispose();
    _descriptionController.dispose(); // Dispose new controller
    _docRefController.dispose(); // Dispose new controller
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateController.text.isNotEmpty
          ? (DateFormat('yyyy-MM-dd').tryParse(_dateController.text) ?? DateTime.now())
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

  Future<void> _pickDocumentFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'], // Added doc/docx
      withData: kIsWeb,
    );

    if (result != null) {
      setState(() {
        if (kIsWeb) {
          _selectedDocumentFileBytes = result.files.single.bytes;
          _selectedDocumentFileName = result.files.single.name;
          _selectedDocumentFile = null;
        } else {
          final path = result.files.single.path;
          if (path != null) {
            _selectedDocumentFile = File(path);
            _selectedDocumentFileName = p.basename(path);
            _selectedDocumentFileBytes = null;
          } else {
            _clearSelectedFile();
          }
        }
      });
    } else {
      // User canceled the picker
    }
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedDocumentFile = null;
      _selectedDocumentFileBytes = null;
      _selectedDocumentFileName = null;
    });
  }

  // New function for AI processing of income documents
  Future<void> _aiProcessIncomeDocument() async {
    if (_selectedDocumentFileBytes == null && _selectedDocumentFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an income document first.')),
      );
      return;
    }

    setState(() {
      _isAiProcessing = true;
    });

    Uint8List? documentBytes = _selectedDocumentFileBytes;
    if (!kIsWeb && _selectedDocumentFile != null) {
      documentBytes = await _selectedDocumentFile!.readAsBytes();
    }

    if (documentBytes != null && _selectedDocumentFileName != null) {
      try {
        // Ensure this URL matches your new income processing backend
        const String apiUrl = 'http://localhost:8004/process-income-document'; 
        var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          documentBytes,
          filename: _selectedDocumentFileName!,
        ));

        final client = http.Client();
        try {
          final streamedResponse = await client.send(request).timeout(const Duration(seconds: 90), // Increased timeout for potentially larger documents/processing
            onTimeout: () {
              throw TimeoutException('The connection to AI service timed out. Please try again.');
            });
          
          final response = await http.Response.fromStream(streamedResponse);
          
          if (response.statusCode == 200) {
            final extractedData = jsonDecode(utf8.decode(response.bodyBytes));
            
            setState(() {
              _dateController.text = extractedData['date']?.toString() ?? _dateController.text;
              _sourceController.text = extractedData['source']?.toString() ?? _sourceController.text;
              _amountController.text = (extractedData['amount'] as num?)?.toString() ?? _amountController.text;
              _typeController.text = extractedData['type']?.toString() ?? _typeController.text;
              _descriptionController.text = extractedData['description']?.toString() ?? _descriptionController.text;
              _docRefController.text = extractedData['document_reference']?.toString() ?? _docRefController.text;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fields auto-filled by AI. Please review.')),
              );
            });
          } else {
            final errorBody = response.body;
            String detail = errorBody;
            try {
              final decodedError = jsonDecode(errorBody);
              if (decodedError is Map && decodedError.containsKey('detail')) {
                detail = decodedError['detail'];
              }
            } catch (_) {}
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('AI processing failed: ${response.statusCode} - $detail')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error calling AI service for income: ${e.toString()}')),
          );
        } finally {
          client.close();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing AI request for income: ${e.toString()}')),
        );
      }
    }

    if(mounted){
      setState(() {
        _isAiProcessing = false;
      });
    }
  }

  Future<void> _submitIncome() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      String? documentStoragePath;

      try {
        if (_selectedDocumentFileBytes != null && _selectedDocumentFileName != null && kIsWeb) {
          documentStoragePath = await _supabaseService.uploadFileBytesToStorage(
            _selectedDocumentFileBytes!,
            _selectedDocumentFileName!,
            'income-bucket', // Corrected bucket name
          );
        } else if (_selectedDocumentFile != null && !kIsWeb) {
          documentStoragePath = await _supabaseService.uploadFileToStorage(
            _selectedDocumentFile!,
            'income-bucket', // Corrected bucket name
          );
        }

        final userId = _supabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated.');
        }

        final incomeData = {
          'date': _dateController.text,
          'source': _sourceController.text,
          'type': _typeController.text,
          'amount': double.tryParse(_amountController.text) ?? 0.0,
          'description': _descriptionController.text, // Add description
          'document_reference': _docRefController.text, // Add document reference
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
          if (documentStoragePath != null)
            'document_storage_path': documentStoragePath,
        };

        // Assuming you have an addIncome method in SupabaseService similar to addExpense
        await _supabaseService.addIncome(incomeData); 

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Income added successfully!')),
          );
          _clearSelectedFile();
          _formKey.currentState?.reset();
          _dateController.clear();
          _sourceController.clear();
          _typeController.clear();
          _amountController.clear();
          _descriptionController.clear(); // Clear new field
          _docRefController.clear(); // Clear new field
          // Consider Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add income: ${e.toString()}')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Income'),
        elevation: 1, // Matched ExpenseEntryScreen
        // Removed custom backgroundColor and foregroundColor to use theme defaults
      ),
      body: Padding( // Added Padding here
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // Changed from SingleChildScrollView -> Column to ListView
            // crossAxisAlignment: CrossAxisAlignment.stretch, // Not applicable to ListView directly
            children: <Widget>[
              // Date Field
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Date',
                  hintText: 'Select income date',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Source Field
              TextFormField(
                controller: _sourceController,
                decoration: InputDecoration(
                  labelText: 'Source',
                  hintText: 'e.g., Employer Name, Client Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the income source';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Type Field
              TextFormField(
                controller: _typeController,
                decoration: InputDecoration(
                  labelText: 'Type',
                  hintText: 'e.g., Salary, Freelance, Investment',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the income type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter income amount',
                  prefixText: 'RM ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the amount';
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

              // Description Field (Optional)
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'e.g., Q1 Services, January Salary',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Document Reference Field (Optional)
              TextFormField(
                controller: _docRefController,
                decoration: InputDecoration(
                  labelText: 'Document Reference (Optional)',
                  hintText: 'e.g., Invoice #INV-2024-001, Payslip ID',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 24),

              // File Picker Section
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Supporting Document (Optional)'),
                onPressed: _isAiProcessing || _isSubmitting ? null : _pickDocumentFile, // Disable if AI processing or submitting
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48), // Make button full width
                  alignment: Alignment.centerLeft, // Align icon and text to the left
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              const SizedBox(height: 8),

              // AI Auto-Fill Button - Enabled only if a file is selected
              if (_selectedDocumentFileName != null) // Show AI button only if a file is selected
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton.icon(
                    icon: _isAiProcessing 
                        ? Container(width: 20, height: 20, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Auto-fill with AI'),
                    onPressed: _isAiProcessing || _isSubmitting ? null : _aiProcessIncomeDocument,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),

              if (_selectedDocumentFileName == null) // Add some space if AI button is not visible
                const SizedBox(height: 16),

              // Display selected file name (moved below AI button)
              if (_selectedDocumentFileName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedDocumentFileName!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: _clearSelectedFile,
                        tooltip: 'Clear selection',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24), // Adjusted from 32 to 24 for consistency

              // Submit Button
              ElevatedButton(
                onPressed: _isAiProcessing || _isSubmitting ? null : _submitIncome, // Disable if AI processing or submitting
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 50), // Make it full width
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                        ),
                      )
                    : const Text('Add Income'), // Text only, icon removed to match ExpenseEntryScreen
              ),
            ],
          ),
        ),
      ),
    );
  }
}
