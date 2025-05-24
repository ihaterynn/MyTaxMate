import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Configuration for items to fetch or calculate
class FinancialItemConfig {
  final String label;
  final bool isBold;
  final bool isCalculated;
  final Map<String, String>? fetchConfig; // {'tableName': 'xxx', 'categoryField': 'yyy', 'categoryValue': 'zzz'}
  final PdfBrush? bgColor;
  final PdfBrush? textColor;
  final bool isNegativeContributionToParentTotal; // e.g. Sales Return is negative for Net Sales

  FinancialItemConfig({
    required this.label,
    this.isBold = false,
    this.isCalculated = false,
    this.fetchConfig,
    this.bgColor,
    this.textColor,
    this.isNegativeContributionToParentTotal = false,
  }) : assert(isCalculated || fetchConfig != null, 'Either isCalculated must be true or fetchConfig must be provided for ${label}');
}

class FinancialStatementPage extends StatefulWidget {
  const FinancialStatementPage({super.key});

  @override
  State<FinancialStatementPage> createState() => _FinancialStatementPageState();
}

class _FinancialStatementPageState extends State<FinancialStatementPage> {
  bool _isLoading = false;

  Future<void> _triggerPdfGeneration() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      if (supabase.auth.currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User not logged in. Please log in to generate the statement.")),
          );
        }
        return;
      }
      final String currentUserId = supabase.auth.currentUser!.id;

      final currentYear = DateTime.now().year;
      // These can be fetched from user settings or passed as parameters
      const String companyName = "Your Company Name Inc.";
      const String companyAddress = "123 Business Rd, Suite 456, Cityville, ST 78900";

      await generateFinancialStatementPdf(
        context: context, // Pass context for potential snackbars from generator
        supabase: supabase,
        userId: currentUserId,
        companyName: companyName,
        companyAddress: companyAddress,
        year1: currentYear - 2, // e.g., 2023
        year2: currentYear - 1, // e.g., 2024
        year3: currentYear,     // e.g., 2025
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Financial statement PDF generated and opened successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating PDF: ${e.toString()}")),
        );
      }
      print("Error in _triggerPdfGeneration: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Statement'),
        backgroundColor: const Color(0xFF17365D), // Dark blue to match PDF
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generate Statement PDF'),
                onPressed: _triggerPdfGeneration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF17365D), // Dark blue
                  foregroundColor: Colors.white, // White text
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
      ),
    );
  }
}

// PDF Generation Logic

Future<double> _fetchTotalAmount({
  required SupabaseClient supabase,
  required String userId,
  required int year,
  required Map<String, String> fetchConfig, // Contains tableName, categoryField, categoryValue
  String dateField = 'date',
  String amountField = 'amount',
}) async {
  final String tableName = fetchConfig['tableName']!;
  final String categoryField = fetchConfig['categoryField']!;
  final String categoryValue = fetchConfig['categoryValue']!;

  final String startDateString = '$year-01-01';
  final String endDateString = '$year-12-31T23:59:59.999'; // Inclusive end for timestamps

  try {
    final List<Map<String, dynamic>> response = await supabase
        .from(tableName)
        .select(amountField)
        .eq('user_id', userId)
        .eq(categoryField, categoryValue)
        .gte(dateField, startDateString)
        .lte(dateField, endDateString);

    double total = 0.0;
    for (var record in response) {
      total += (record[amountField] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  } catch (e) {
    print('Error fetching $tableName for $categoryValue in $year (user: $userId): $e');
    return 0.0;
  }
}

Future<void> generateFinancialStatementPdf({
  required BuildContext context, // For snackbars if needed from here
  required SupabaseClient supabase,
  required String userId,
  required String companyName,
  required String companyAddress,
  required int year1,
  required int year2,
  required int year3,
}) async {
  PdfDocument document = PdfDocument();
  final PdfPage page = document.pages.add();
  final Size pageSize = page.getClientSize();
  final PdfGraphics graphics = page.graphics;

  // Define Colors and Fonts
  final PdfBrush blueBrush = PdfSolidBrush(PdfColor(23, 54, 93));
  final PdfBrush whiteBrush = PdfSolidBrush(PdfColor(255, 255, 255));
  final PdfBrush blackBrush = PdfSolidBrush(PdfColor(0, 0, 0));

  final PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
  final PdfFont normalFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
  final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
  
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$ ');
  final dateFormat = DateFormat('dd MMM, yyyy'); // Corrected date format
  final String currentDate = dateFormat.format(DateTime.now());

  // --- Header Section ---
  graphics.drawRectangle(brush: blueBrush, bounds: Rect.fromLTWH(0, 0, pageSize.width, 60));
  graphics.drawString(
    companyName, headerFont, brush: whiteBrush,
    bounds: Rect.fromLTWH(20, 15, pageSize.width * 0.6 - 20, 40),
    format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle), // Removed clipPath: true
  );
  graphics.drawString(
    'Income Statement', headerFont, brush: whiteBrush,
    bounds: Rect.fromLTWH(pageSize.width * 0.5, 15, pageSize.width * 0.5 - 20, 40),
    format: PdfStringFormat(alignment: PdfTextAlignment.right, lineAlignment: PdfVerticalAlignment.middle),
  );
  graphics.drawString(
    'Address: $companyAddress', normalFont, brush: blackBrush,
    bounds: Rect.fromLTWH(20, 70, pageSize.width - 40, 20),
  );
  
  const double dateBlockWidth = 110;
  const double dateSpacing = 10;
  graphics.drawString(
    'Date Created: $currentDate', normalFont, brush: blackBrush,
    bounds: Rect.fromLTWH(pageSize.width - (dateBlockWidth * 2) - dateSpacing - 20, 70, dateBlockWidth, 20),
    format: PdfStringFormat(alignment: PdfTextAlignment.right),
  );
  graphics.drawString(
    'Date Issued: $currentDate', normalFont, brush: blackBrush,
    bounds: Rect.fromLTWH(pageSize.width - dateBlockWidth - 20, 70, dateBlockWidth, 20),
    format: PdfStringFormat(alignment: PdfTextAlignment.right),
  );

  // --- Income Statement Section Title Bar ---
  graphics.drawRectangle(brush: blueBrush, bounds: Rect.fromLTWH(0, 100, pageSize.width, 30));
  graphics.drawString(
    'Income Statement', boldFont, brush: whiteBrush,
    bounds: Rect.fromLTWH(20, 100, pageSize.width - 40, 30),
    format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle),
  );

  // --- Financial Data Table ---
  final PdfGrid grid = PdfGrid();
  grid.columns.add(count: 4);
  grid.columns[0].width = pageSize.width * 0.50; // Description
  grid.columns[1].width = pageSize.width * 0.16; // Year 1
  grid.columns[2].width = pageSize.width * 0.16; // Year 2
  grid.columns[3].width = pageSize.width * 0.16; // Year 3 (Adjusted to sum to < 1.0 if borders/padding exist)

  final PdfGridRow headerGridRow = grid.headers.add(1)[0];
  headerGridRow.cells[0].value = 'Description';
  headerGridRow.cells[1].value = year1.toString();
  headerGridRow.cells[2].value = year2.toString();
  headerGridRow.cells[3].value = year3.toString();

  headerGridRow.style.font = boldFont;
  headerGridRow.style.backgroundBrush = blueBrush;
  headerGridRow.style.textBrush = whiteBrush;
  for (int i = 0; i < headerGridRow.cells.count; i++) {
    headerGridRow.cells[i].style.stringFormat = PdfStringFormat(alignment: i == 0 ? PdfTextAlignment.left : PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle);
    if (i == 0) headerGridRow.cells[i].style.cellPadding = PdfPaddings(left: 5, right: 2, top: 2, bottom: 2); // Padding for description
  }
  
  // Define financial items structure
  final List<FinancialItemConfig> financialItems = [
    // Revenue
    FinancialItemConfig(label: 'Sales', fetchConfig: {'tableName': 'income', 'categoryField': 'type', 'categoryValue': 'Sales'}), // Assuming 'type' field for income categories
    FinancialItemConfig(label: 'Less: Sales Return', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Sales Return'}, isNegativeContributionToParentTotal: true),
    FinancialItemConfig(label: 'Less: Discounts and Allowances', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Discounts and Allowances'}, isNegativeContributionToParentTotal: true),
    FinancialItemConfig(label: 'Net Sales', isBold: true, isCalculated: true),
    FinancialItemConfig(label: 'Cost of Goods Sold', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Cost of Goods Sold'}),
    FinancialItemConfig(label: 'Gross Profit', isBold: true, isCalculated: true),
    // Operating Expenses Section Header (drawn manually or as a special grid row if preferred)
    // For simplicity, items are listed directly. A visual separator row could be added.
    FinancialItemConfig(label: 'Advertising', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Advertising'}),
    FinancialItemConfig(label: 'Auto Expenses', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Auto Expenses'}),
    FinancialItemConfig(label: 'Bank Fees', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Bank Fees'}),
    FinancialItemConfig(label: 'Education & Meetings', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Education & Meetings'}),
    FinancialItemConfig(label: 'Insurance', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Insurance'}),
    FinancialItemConfig(label: 'Interest Paid (Operating)', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Interest Paid'}), // Clarify if this is operating vs other
    FinancialItemConfig(label: 'Meals', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Meals'}),
    FinancialItemConfig(label: 'Office Supplies', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Office Supplies'}),
    FinancialItemConfig(label: 'Rent/Lease', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Rent/Lease'}),
    FinancialItemConfig(label: 'Repairs and Maintenance', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Repairs and Maintenance'}),
    FinancialItemConfig(label: 'Taxes & Licenses (Operating)', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Taxes & Licenses'}),
    FinancialItemConfig(label: 'Travel', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Travel'}),
    FinancialItemConfig(label: 'Telecommunications', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Telecommunications'}),
    FinancialItemConfig(label: 'Utilities', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Utilities'}),
    FinancialItemConfig(label: 'Wages', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Wages'}),
    FinancialItemConfig(label: 'Payroll Taxes', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Payroll Taxes'}),
    FinancialItemConfig(label: 'Total Operating Expenses', isBold: true, isCalculated: true, bgColor: blueBrush, textColor: whiteBrush),
    FinancialItemConfig(label: 'Operating Profit (Loss)', isBold: true, isCalculated: true, bgColor: blueBrush, textColor: whiteBrush),
    // Other Income and Expenses
    FinancialItemConfig(label: 'Interest Income', fetchConfig: {'tableName': 'income', 'categoryField': 'type', 'categoryValue': 'Interest Income'}),
    FinancialItemConfig(label: 'Other Income', fetchConfig: {'tableName': 'income', 'categoryField': 'type', 'categoryValue': 'Other Income'}),
    FinancialItemConfig(label: 'Other Expenses', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Other Expenses'}, isNegativeContributionToParentTotal: true),
    FinancialItemConfig(label: 'Depreciation', fetchConfig: {'tableName': 'expenses', 'categoryField': 'category', 'categoryValue': 'Depreciation'}, isNegativeContributionToParentTotal: true), // Typically an expense
    FinancialItemConfig(label: 'Total Other Income and Expenses', isBold: true, isCalculated: true),
    FinancialItemConfig(label: 'Net Profit (Loss)', isBold: true, isCalculated: true),
  ];

  Map<int, Map<String, double>> yearlyData = {};
  final List<int> years = [year1, year2, year3];

  for (int year in years) {
    yearlyData[year] = {};
    Map<String, double> currentYearValues = {};

    // Fetch data
    for (var item in financialItems) {
      if (item.fetchConfig != null) {
        double amount = await _fetchTotalAmount(
          supabase: supabase, userId: userId, year: year, fetchConfig: item.fetchConfig!,
        );
        currentYearValues[item.label] = amount;
      }
    }

    // Perform calculations
    double sales = currentYearValues['Sales'] ?? 0;
    double salesReturn = currentYearValues['Less: Sales Return'] ?? 0;
    double discounts = currentYearValues['Less: Discounts and Allowances'] ?? 0;
    currentYearValues['Net Sales'] = sales - salesReturn - discounts;

    double cogs = currentYearValues['Cost of Goods Sold'] ?? 0;
    currentYearValues['Gross Profit'] = currentYearValues['Net Sales']! - cogs;
    
    double totalOpEx = 0;
    int grossProfitIdx = financialItems.indexWhere((el) => el.label == 'Gross Profit');
    int totalOpExIdx = financialItems.indexWhere((el) => el.label == 'Total Operating Expenses');
    for(int i = grossProfitIdx + 1; i < totalOpExIdx; i++) {
        String currentLabel = financialItems[i].label;
        totalOpEx += (currentYearValues[currentLabel] ?? 0);
    }
    currentYearValues['Total Operating Expenses'] = totalOpEx;
    currentYearValues['Operating Profit (Loss)'] = currentYearValues['Gross Profit']! - totalOpEx;

    double interestIncome = currentYearValues['Interest Income'] ?? 0;
    double otherIncome = currentYearValues['Other Income'] ?? 0;
    double otherExpenses = currentYearValues['Other Expenses'] ?? 0;
    double depreciation = currentYearValues['Depreciation'] ?? 0;
    currentYearValues['Total Other Income and Expenses'] = (interestIncome + otherIncome) - (otherExpenses + depreciation);
    
    currentYearValues['Net Profit (Loss)'] = currentYearValues['Operating Profit (Loss)']! + currentYearValues['Total Other Income and Expenses']!;
    
    yearlyData[year] = currentYearValues;
  }

  // Add rows to the grid
  for (var item in financialItems) {
    final PdfGridRow row = grid.rows.add();
    row.cells[0].value = item.label;
    row.cells[0].style.stringFormat = PdfStringFormat(alignment: PdfTextAlignment.left, lineAlignment: PdfVerticalAlignment.middle);
    row.cells[0].style.cellPadding = PdfPaddings(left: 5, right: 2, top: 2, bottom: 2);


    if (item.isBold) row.cells[0].style.font = boldFont;
    if (item.bgColor != null) row.cells[0].style.backgroundBrush = item.bgColor;
    if (item.textColor != null) row.cells[0].style.textBrush = item.textColor;

    for (int j = 0; j < years.length; j++) {
      double value = yearlyData[years[j]]![item.label] ?? 0.0;
      // For "Less: ..." items, display as positive but they are subtracted in calculations
      // Or, if you prefer to show them as (XXX.XX), format accordingly. Here, they are shown as positive.
      row.cells[j + 1].value = currencyFormat.format(value);
      row.cells[j + 1].style.stringFormat = PdfStringFormat(alignment: PdfTextAlignment.right, lineAlignment: PdfVerticalAlignment.middle);
      if (item.isBold) row.cells[j+1].style.font = boldFont;
      if (item.bgColor != null) row.cells[j+1].style.backgroundBrush = item.bgColor;
      if (item.textColor != null) row.cells[j+1].style.textBrush = item.textColor;
    }
  }
  
  // Draw grid
  grid.draw(
    page: page,
    bounds: Rect.fromLTWH(0, 140, pageSize.width, pageSize.height - 140 - 40), // Y: 100(title bar Y) + 30(title bar H) + 10(padding) = 140. Height: available - footer
  );

  // --- Footer Section ---
  final double footerY = pageSize.height - 30;
  graphics.drawRectangle(brush: blueBrush, bounds: Rect.fromLTWH(0, footerY, pageSize.width, 30));
  graphics.drawString(
    'Generated by MyApp © ${DateTime.now().year}', // Example footer text
    normalFont, // Using normalFont for footer, can be boldFont
    brush: whiteBrush,
    bounds: Rect.fromLTWH(pageSize.width - 200 - 20, footerY + 5 , 200, 20), // Positioned right
    format: PdfStringFormat(alignment: PdfTextAlignment.right, lineAlignment: PdfVerticalAlignment.middle),
  );
  
  // Save and Open
  List<int> bytes = await document.save();
  document.dispose();

  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path;
  final file = File('$path/Financial_Statement_${userId}_${year3}.pdf');
  await file.writeAsBytes(bytes);
  
  try {
    OpenFile.open(file.path);
  } catch (e) {
    print('Error opening file: $e');
    if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open PDF. Saved at: ${file.path}')),
      );
    }
  }
}
