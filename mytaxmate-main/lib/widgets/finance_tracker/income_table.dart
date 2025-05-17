import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main.dart'; // Add for AppGradients
import '../../models/income.dart';
import '../../screens/income_entry_screen.dart'; // Add for navigation

class IncomeTable extends StatelessWidget {
  final List<Income> incomes;
  final bool isLoading;
  final String? error;
  final VoidCallback onReload;
  final Function(String) onViewDocument; // Callback to view/download document

  const IncomeTable({
    super.key,
    required this.incomes,
    required this.isLoading,
    this.error,
    required this.onReload,
    required this.onViewDocument,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobileView = MediaQuery.of(context).size.width < 600;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary), // Use secondary color for income
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.error.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Incomes', // Changed from Expenses
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.blueGradient, // Use green gradient
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.2), // Use secondary color shadow
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: onReload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (incomes.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3)), // Use secondary color border
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.05), // Use secondary color background
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined, // Icon for income
                  size: 40,
                  color: Theme.of(context).colorScheme.secondary, // Use secondary color
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Income Found', // Changed from Expenses
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a record to get started tracking your income!', // Changed text
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5F6368)),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.greenGradient, // Use green gradient
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.2), // Use secondary color shadow
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_card_outlined), // Icon for adding income
                  label: const Text('Add First Income'), // Changed text
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IncomeEntryScreen(),
                      ),
                    ).then((_) => onReload());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isMobileView) {
      // Mobile View: ListView of tappable items
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: incomes.length,
        itemBuilder: (context, index) {
          final income = incomes[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: InkWell(
              onTap: () {
                // Potentially navigate to a detailed view or edit screen
                // For now, just prints or could show a dialog
                print('Tapped on income: ${income.source}');
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          income.source,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.secondary, // Use secondary color
                              ),
                        ),
                        Text(
                          'RM ${income.amount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary, // Use secondary color
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Type: ${income.type}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(income.date))}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    if (income.documentStoragePath != null && income.documentStoragePath!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: Icon(Icons.description_outlined, size: 18, color: Theme.of(context).colorScheme.secondary), // Use secondary color
                            label: Text('View Document', style: TextStyle(color: Theme.of(context).colorScheme.secondary)), // Use secondary color
                            onPressed: () => onViewDocument(income.documentStoragePath!),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Desktop/Wide View: DataTable
    return LayoutBuilder(
      builder: (context, constraints) {
        // bool isWide = constraints.maxWidth > 600; // No longer needed
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8.0), // Added padding
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 16), // Adjusted for padding
              child: DataTable(
                columnSpacing: 16.0, // Changed from adaptive to fixed
                headingRowHeight: 48.0, // Added
                dataRowMinHeight: 52.0, // Added
                dataRowMaxHeight: 52.0, // Added
                // headingRowColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) { // REMOVED
                //   return Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3);
                // }),
                headingTextStyle: Theme.of(context).textTheme.titleSmall?.copyWith( // CHANGED
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Amount', textAlign: TextAlign.right)),
                  DataColumn(label: Text('Document')),
                  // Add more columns as needed, e.g., Actions
                ],
                rows: incomes.map((income) {
                  return DataRow(
                    cells: [
                      DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.parse(income.date)))),
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                              child: Text(
                                income.source.isNotEmpty
                                    ? income.source[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                income.source,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(_buildTypeChip(context, income.type)), // Changed to use chip
                      DataCell(Text('RM ${income.amount.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                      DataCell(
                        income.documentStoragePath != null && income.documentStoragePath!.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.secondary), // Use secondary color
                                onPressed: () => onViewDocument(income.documentStoragePath!),
                                tooltip: 'View Document',
                              )
                            : const Text('N/A', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Helper widget for income type chip
Widget _buildTypeChip(BuildContext context, String type) {
  return Chip(
    label: Text(type),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    labelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.8),
    ),
    backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );
}
