import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

Future<void> generateAndOpenHelloWorldPdf(BuildContext context) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (pw.Context context) => pw.Center(child: pw.Text('Hello World')),
    ),
  );

  // Convert the PDF to bytes
  final Uint8List pdfBytes = await pdf.save();

  // Use the printing package to preview or print the PDF
  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
}

Future<void> generateIncomeStatementPdf({
  required BuildContext context,
  required String period,
  required List<Map<String, dynamic>> incomes,
  required List<Map<String, dynamic>> expenses,
  String companyName = 'MyTaxMate Company',
  String companyAddress = '123 Street Avenue, Cityville, State, 12333',
}) async {
  final pdf = pw.Document();

  // Colors and styles
  final PdfColor darkBlue = PdfColor.fromInt(0xFF003A6B);
  final PdfColor lightBlue = PdfColor.fromInt(0xFF3776A1);
  final PdfColor headerGray = PdfColors.grey300;
  final PdfColor white = PdfColors.white;
  final double baseFont = 10;
  final double headerFont = 16;
  final double sectionFont = 12;

  // Load logo image
  final logoBytes = await DefaultAssetBundle.of(
    context,
  ).load('assets/images/mytaxmate-logo.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

  // Calculate totals
  double totalIncome = incomes.fold(
    0.0,
    (sum, item) => sum + (item['amount'] as num).toDouble(),
  );
  double totalExpenses = expenses.fold(
    0.0,
    (sum, item) => sum + (item['amount'] as num).toDouble(),
  );
  double netCashFlow = totalIncome - totalExpenses;

  // Date info
  final now = DateTime.now();
  final dateCreated = period;
  final dateIssued =
      '${now.day.toString().padLeft(2, '0')} ${_monthName(now.month)}, ${now.year}';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build:
          (pw.Context context) => [
            // Logo and Income Statement title in one row
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logoImage, height: 28),
                pw.Text(
                  'Income Statement',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 22,
                    color: darkBlue,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            // Date info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Date Created:',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(dateCreated, style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Date Issued:',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(dateIssued, style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            // Section: Income
            _sectionHeader('Income', darkBlue, white, sectionFont),
            _tableWithStriping(
              headers: ['Date', 'Source', 'Type', 'Amount'],
              data:
                  incomes
                      .map(
                        (income) => [
                          (income['date'] ?? '').toString(),
                          (income['source'] ?? '').toString(),
                          (income['type'] ?? '').toString(),
                          'RM${(income['amount'] as num).toStringAsFixed(2)}',
                        ],
                      )
                      .toList(),
              colAlign: [
                pw.Alignment.centerLeft,
                pw.Alignment.centerLeft,
                pw.Alignment.centerLeft,
                pw.Alignment.centerLeft, // Amount right-aligned
              ],
              baseFont: baseFont,
            ),
            pw.SizedBox(height: 12),
            // Section: Expenses
            _sectionHeader('Expenses', darkBlue, white, sectionFont),
            _tableWithStriping(
              headers: ['Date', 'Merchant', 'Category', 'Amount', 'Deductible'],
              data:
                  expenses
                      .map(
                        (expense) =>
                            [
                                  (expense['date'] ?? '').toString(),
                                  (expense['merchant'] ?? '').toString(),
                                  (expense['category'] ?? '').toString(),
                                  'RM${(expense['amount'] as num).toStringAsFixed(2)}',
                                  ((expense['is_deductible'] == true ||
                                              expense['is_deductible'] == 1)
                                          ? 'Yes'
                                          : 'No')
                                      .toString(),
                                ]
                      )
                      .toList(),
              colAlign: [
                pw.Alignment.centerLeft,
                pw.Alignment.centerLeft,
                pw.Alignment.centerLeft,
                pw.Alignment.centerLeft, // Amount right-aligned
                pw.Alignment.centerLeft, // Deductible center-aligned
              ],
              baseFont: baseFont,
            ),
            pw.SizedBox(height: 18),
            // Summary
            _sectionHeader('Summary', lightBlue, white, sectionFont),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _summaryRow(
                    'Total Income:',
                    'RM${totalIncome.toStringAsFixed(2)}',
                    fontSize: baseFont,
                  ),
                  _summaryRow(
                    'Total Expenses:',
                    'RM${totalExpenses.toStringAsFixed(2)}',
                    fontSize: baseFont,
                  ),
                  pw.Divider(),
                  _summaryRow(
                    'Net Cash Flow:',
                    'RM${netCashFlow.toStringAsFixed(2)}',
                    fontSize: baseFont + 2,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ],
    ),
  );

  final Uint8List pdfBytes = await pdf.save();
  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

pw.Widget _sectionHeader(
  String title,
  PdfColor bg,
  PdfColor fg,
  double fontSize,
) {
  return pw.Container(
    width: double.infinity,
    color: bg,
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        color: fg,
        fontWeight: pw.FontWeight.bold,
        fontSize: fontSize,
      ),
    ),
  );
}

pw.Widget _summaryRow(
  String label,
  String value, {
  double fontSize = 10,
  bool isBold = false,
}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  );
}

pw.Widget _tableWithStriping({
  required List<String> headers,
  required List<List<String>> data,
  required List<pw.Alignment> colAlign,
  double baseFont = 10,
}) {
  return pw.Table(
    border: null,
    columnWidths: {
      for (int i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth(),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF3776A1)),
        children: [
          for (int i = 0; i < headers.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 4,
              ),
              child: pw.Text(
                headers[i],
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: baseFont,
                ),
              ),
            ),
        ],
      ),
      ...List.generate(data.length, (rowIdx) {
        final isEven = rowIdx % 2 == 0;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.white : PdfColors.grey100,
          ),
          children: [
            for (int colIdx = 0; colIdx < headers.length; colIdx++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: 4,
                ),
                child: pw.Align(
                  alignment: colAlign[colIdx],
                  child: pw.Text(
                    data[rowIdx][colIdx],
                    style: pw.TextStyle(fontSize: baseFont),
                  ),
                ),
              ),
          ],
        );
      }),
    ],
  );
}
