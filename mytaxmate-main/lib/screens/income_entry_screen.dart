import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mytaxmate/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

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
  bool _isSubmitting = false;

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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 24),

              // File Picker
              Text(
                'Attach Document (Optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDocumentFileName ?? 'No file selected',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedDocumentFileName != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.redAccent),
                        onPressed: _clearSelectedFile,
                        tooltip: 'Clear selection',
                      ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Select File'),
                      onPressed: _pickDocumentFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt_outlined),
                      label: const Text('Add Income'),
                      onPressed: _submitIncome,
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
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
