import 'package:flutter/material.dart';
import '../../models/expense.dart';

class ExpenseCategories extends StatelessWidget {
  final List<Expense> expenses;
  final bool isLoading;
  final String? error;

  const ExpenseCategories({
    Key? key,
    required this.expenses,
    required this.isLoading,
    this.error,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text('Error loading expenses: $error'));
    }
    if (expenses.isEmpty) {
      return const Center(child: Text('No expenses recorded yet.'));
    }

    // Group expenses by category
    Map<String, List<Expense>> expensesByCategory = {};
    for (var expense in expenses) {
      if (expensesByCategory.containsKey(expense.category)) {
        expensesByCategory[expense.category]!.add(expense);
      } else {
        expensesByCategory[expense.category] = [expense];
      }
    }

    // Calculate total for each category
    Map<String, double> categoryTotals = {};
    expensesByCategory.forEach((category, expenses) {
      categoryTotals[category] = expenses.fold(
        0.0,
        (sum, item) => sum + item.amount,
      );
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Expense Categories",
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...expensesByCategory.entries.map((entry) {
              String category = entry.key;
              List<Expense> categoryExpenses = entry.value;
              double total = categoryTotals[category]!;

              return _buildCategoryItem(
                category,
                'RM ${total.toStringAsFixed(2)}',
                isHeader: true,
                key: PageStorageKey(
                  category,
                ), // Explicit key for category header
                items:
                    categoryExpenses.map((expense) {
                      // Removed .asMap().entries and idx as ObjectKey(expense) should be sufficient
                      return _buildCategoryItem(
                        expense.merchant, // Display merchant or description
                        'RM ${expense.amount.toStringAsFixed(2)}',
                        key: ObjectKey(
                          expense,
                        ), // Use ObjectKey for unique expense items
                      );
                    }).toList(),
              );
            }),
          ],
        ), // End of main Column
      ), // End of Padding
    ); // End of Card
  }

  Widget _buildCategoryItem(
    String title,
    String amount, {
    bool isHeader = false,
    List<Widget>? items,
    Key? key, // Key is now directly passed and used
  }) {
    return ExpansionTile(
      key: key, // Directly use the key passed by the caller
      initiallyExpanded:
          isHeader, // Keep initiallyExpanded for headers, consider for sub-items if needed
      tilePadding: EdgeInsets.only(
        left: isHeader ? 0 : 16,
        right: 0,
        top: isHeader ? 4 : 0,
        bottom: isHeader ? 4 : 0,
      ),
      childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Wrap in Flexible to prevent overflow
          Flexible(
            flex: 3,
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                fontSize: isHeader ? 15 : 14,
                color: isHeader ? Colors.black87 : Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8), // Add some spacing
          // Wrap in Flexible with tight constraints for the amount
          Flexible(
            flex: 2,
            child: Text(
              amount,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                fontSize: isHeader ? 15 : 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      trailing:
          (items != null && items.isNotEmpty)
              ? Icon(Icons.expand_more, color: Colors.grey[600])
              : const SizedBox.shrink(),
      iconColor: Colors.grey[600],
      collapsedIconColor: Colors.grey[600],
      children: items ?? [],
    );
  }
}
