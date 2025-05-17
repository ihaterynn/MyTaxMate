import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../models/expense.dart';
import '../../screens/upload_options_screen.dart';

class ExpensesTable extends StatelessWidget {
  final List<Expense> expenses;
  final bool isLoading;
  final String? error;
  final Function() onReload;
  final Function(String) onViewReceipt;

  const ExpensesTable({
    Key? key,
    required this.expenses,
    required this.isLoading,
    this.error,
    required this.onReload,
    required this.onViewReceipt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isMobileView = MediaQuery.of(context).size.width < 600;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF3776A1)),
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
                'Error Loading Expenses',
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
                  gradient: AppGradients.blueGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF003A6B).withOpacity(0.2),
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

    if (expenses.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF89CFF1).withOpacity(0.3)),
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
                  color: const Color(0xFF003A6B).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: Color(0xFF3776A1),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Expenses Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a record to get started tracking your expenses!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5F6368)),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.blueGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF003A6B).withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Expense'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExpenseEntryScreen(),
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
        shrinkWrap:
            true, // Important if ListView is inside another scrollable or has unbounded height
        physics:
            const NeverScrollableScrollPhysics(), // If parent is already scrollable (like CustomScrollView)
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          return _buildMobileExpenseListItem(expense, context);
        },
      );
    } else {
      // Desktop View: DataTable
      return LayoutBuilder(
        builder: (context, constraints) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth - 16,
                ),
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 48,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 52,
                  headingTextStyle: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Merchant')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Tax Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows:
                      expenses.map((expense) {
                        return DataRow(
                          cells: [
                            DataCell(Text(expense.date)),
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.grey[200],
                                    foregroundColor: Colors.grey[700],
                                    child: Text(
                                      expense.merchant.isNotEmpty
                                          ? expense.merchant[0]
                                          : '?',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      expense.merchant,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(_buildCategoryChip(expense.category)),
                            DataCell(
                              Text('RM ${expense.amount.toStringAsFixed(2)}'),
                            ),
                            DataCell(
                              _buildStatusChip(
                                expense.isDeductible
                                    ? 'Deductible'
                                    : 'Non-Deductible',
                                expense.isDeductible
                                    ? Colors.green
                                    : Colors.redAccent,
                              ),
                            ),
                            DataCell(
                              (expense.receiptStoragePath != null &&
                                      expense.receiptStoragePath!.isNotEmpty)
                                  ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        iconSize: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        color: Colors.blue,
                                        tooltip: 'View Receipt',
                                        onPressed:
                                            () => onViewReceipt(
                                              expense.receiptStoragePath!,
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.download_outlined,
                                        ),
                                        iconSize: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        color: Colors.green,
                                        tooltip: 'Download Receipt',
                                        onPressed:
                                            () => onViewReceipt(
                                              expense.receiptStoragePath!,
                                            ),
                                      ),
                                    ],
                                  )
                                  : const SizedBox.shrink(),
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

  // New method for mobile list item
  Widget _buildMobileExpenseListItem(Expense expense, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6.0),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showExpenseDetailsDialog(context, expense),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      expense.merchant,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202124),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RM ${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3776A1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF89CFF1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      expense.date,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF3776A1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildStatusChip(
                    expense.isDeductible ? 'Deductible' : 'Non-Deductible',
                    expense.isDeductible
                        ? const Color(0xFF34A853)
                        : const Color(0xFFEA4335),
                  ),
                ],
              ),
              if (expense.category.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        size: 14,
                        color: const Color(0xFF5F6368),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          expense.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5F6368),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (expense.receiptStoragePath != null &&
                          expense.receiptStoragePath!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: InkWell(
                            onTap:
                                () =>
                                    onViewReceipt(expense.receiptStoragePath!),
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_outlined,
                                  size: 14,
                                  color: const Color(0xFF3776A1),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'View Receipt',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF3776A1),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // New method for expense details dialog
  void _showExpenseDetailsDialog(BuildContext context, Expense expense) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            expense.merchant,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF202124),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('Date:', expense.date),
                _buildDetailRow(
                  'Amount:',
                  'RM ${expense.amount.toStringAsFixed(2)}',
                ),
                _buildDetailRow('Category:', expense.category),
                _buildDetailRow(
                  'Tax Deductible:',
                  expense.isDeductible ? 'Yes' : 'No',
                  valueColor:
                      expense.isDeductible
                          ? const Color(0xFF34A853)
                          : const Color(0xFFEA4335),
                ),
                _buildDetailRow(
                  'Created At:',
                  DateFormat.yMMMd().add_jm().format(expense.createdAt),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            if (expense.receiptStoragePath != null &&
                expense.receiptStoragePath!.isNotEmpty) ...[
              TextButton.icon(
                icon: const Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFF3776A1),
                ),
                label: const Text(
                  'View Receipt',
                  style: TextStyle(color: Color(0xFF3776A1)),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog first
                  onViewReceipt(expense.receiptStoragePath!);
                },
              ),
              TextButton.icon(
                icon: const Icon(
                  Icons.download_outlined,
                  color: Color(0xFF34A853),
                ),
                label: const Text(
                  'Download',
                  style: TextStyle(color: Color(0xFF34A853)),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog first
                  onViewReceipt(expense.receiptStoragePath!);
                },
              ),
            ],
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF5F6368),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF202124),
                fontSize: 14,
                fontWeight:
                    valueColor != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    Color chipColor;
    Color textColor;

    // Assign colors based on category for visual consistency
    switch (label.toLowerCase()) {
      case 'workspace':
        chipColor = const Color(0xFF6EB1D6).withOpacity(0.1);
        textColor = const Color(0xFF1B5886);
        break;
      case 'software':
        chipColor = const Color(0xFF89CFF1).withOpacity(0.1);
        textColor = const Color(0xFF3776A1);
        break;
      case 'meals':
        chipColor = const Color(0xFF003A6B).withOpacity(0.1);
        textColor = const Color(0xFF003A6B);
        break;
      default:
        chipColor = const Color(0xFF5293B8).withOpacity(0.1);
        textColor = const Color(0xFF3776A1);
    }

    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Chip(
      avatar: Icon(
        label == 'Deductible' ? Icons.check_circle : Icons.cancel,
        color: color,
        size: 14,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
