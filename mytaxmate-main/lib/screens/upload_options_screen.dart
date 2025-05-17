import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mytaxmate/services/supabase_service.dart';
import '../main.dart'; // Import for AppGradients
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
// Consider adding a UUID package if client-side ID generation is needed:
// import 'package:uuid/uuid.dart';

class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  final _dateController = TextEditingController();
  final _merchantController = TextEditingController();
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isDeductible = false;
  bool _isSubmitting = false;

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
              ? (DateFormat('yyyy-MM-dd').tryParse(_dateController.text) ??
                  DateTime.now())
              : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF3776A1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF202124),
            ),
          ),
          child: child!,
        );
      },
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
      if (kIsWeb) {
        // Web: Get bytes and name
        final fileBytes = result.files.single.bytes;
        final fileName = result.files.single.name;
        setState(() {
          _selectedReceiptFileBytes = fileBytes;
          _selectedReceiptFileName = fileName;
          _selectedReceiptFile = null; // Clear non-web file object
        });
      } else {
        // Non-web: Get path
        final path = result.files.single.path;
        if (path != null) {
          setState(() {
            _selectedReceiptFile = File(path);
            _selectedReceiptFileBytes = null; // Clear web bytes
            _selectedReceiptFileName = null; // Clear web name
          });
        } else {
          _clearSelectedFile();
        }
      }
    } else {
      _clearSelectedFile();
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
        if (kIsWeb &&
            _selectedReceiptFileBytes != null &&
            _selectedReceiptFileName != null) {
          // Web: Upload bytes
          receiptStoragePath = await _supabaseService.uploadFileBytesToStorage(
            _selectedReceiptFileBytes!,
            _selectedReceiptFileName!,
            'receipts-bucket',
          );
          print('Uploaded receipt (web) to: $receiptStoragePath');
        } else if (!kIsWeb && _selectedReceiptFile != null) {
          // Non-web: Upload file
          receiptStoragePath = await _supabaseService.uploadFileToStorage(
            _selectedReceiptFile!,
            'receipts-bucket',
          );
          print('Uploaded receipt to: $receiptStoragePath');
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
            const SnackBar(
              content: Text('Expense added successfully!'),
              backgroundColor: Color(0xFF3776A1),
            ),
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
            SnackBar(
              content: Text('Failed to add expense: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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

  void _aiGeneratePlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI Generation feature coming soon!'),
        backgroundColor: Color(0xFF3776A1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Expense'), elevation: 0),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, const Color(0xFF89CFF1).withOpacity(0.05)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                // Form header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003A6B).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF003A6B).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        color: const Color(0xFF3776A1),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Expense Record',
                              style: TextStyle(
                                color: const Color(0xFF202124),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fill in the details below to record your expense',
                              style: TextStyle(
                                color: const Color(0xFF5F6368),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Date field
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    hintText: 'Select expense date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.calendar_today,
                      color: const Color(0xFF3776A1),
                    ),
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

                // Merchant field
                TextFormField(
                  controller: _merchantController,
                  decoration: InputDecoration(
                    labelText: 'Merchant',
                    hintText: 'Enter merchant name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.store,
                      color: const Color(0xFF3776A1),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter merchant name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category field
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    hintText: 'Enter expense category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.category,
                      color: const Color(0xFF3776A1),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Amount field
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Enter amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.payments_outlined,
                      color: const Color(0xFF3776A1),
                    ),
                    prefixText: 'RM ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    if (double.parse(value) <= 0) {
                      return 'Amount must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Receipt upload
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receipt Attachment',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: const Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickReceiptFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF89CFF1).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF89CFF1).withOpacity(0.3),
                              width: 1,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.upload_file,
                                size: 40,
                                color: const Color(0xFF3776A1),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Click to upload receipt',
                                style: TextStyle(
                                  color: const Color(0xFF3776A1),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Supported formats: PDF, JPG, PNG',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedReceiptFileName != null ||
                          _selectedReceiptFile != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003A6B).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file_outlined,
                                size: 18,
                                color: const Color(0xFF3776A1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  kIsWeb
                                      ? (_selectedReceiptFileName ??
                                          'No file selected.')
                                      : (_selectedReceiptFile == null
                                          ? 'No file selected.'
                                          : p.basename(
                                            _selectedReceiptFile!.path,
                                          )),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF3776A1),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: _clearSelectedFile,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tax deductible switch
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: SwitchListTile(
                    title: const Text('Tax Deductible Expense'),
                    subtitle: Text(
                      'Mark this expense as tax deductible',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    value: _isDeductible,
                    onChanged: (bool value) {
                      setState(() {
                        _isDeductible = value;
                      });
                    },
                    activeColor: const Color(0xFF3776A1),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit button
                if (_isSubmitting)
                  const Center(child: CircularProgressIndicator())
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.blueGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003A6B).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt_outlined),
                      label: const Text('Submit Expense'),
                      onPressed: _submitExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // AI Generate button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF34A853),
                        const Color(0xFF1B5886),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('AI Generate from Receipt'),
                    onPressed: _aiGeneratePlaceholder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
