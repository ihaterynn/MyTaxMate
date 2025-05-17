import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../screens/placeholder_screen.dart'; 
// import '../../screens/expense_entry_screen.dart'; // Removed as it doesn't exist
import '../../screens/income_entry_screen.dart';
import '../../models/expense.dart';
import '../../models/income.dart';

class SummaryCards extends StatelessWidget {
  final List<Expense> expenses;
  final List<Income> incomes;
  final bool isLoadingExpenses;
  final bool isLoadingIncomes;
  final String? errorExpenses;
  final String? errorIncomes;
  final Function() onReloadExpenses;
  final Function() onReloadIncomes;

  const SummaryCards({
    Key? key,
    required this.expenses,
    required this.incomes,
    required this.isLoadingExpenses,
    required this.isLoadingIncomes,
    this.errorExpenses,
    this.errorIncomes,
    required this.onReloadExpenses,
    required this.onReloadIncomes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Handle the case where incomes might be null
    final List<Income> safeIncomes = incomes ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        bool useColumnLayout = constraints.maxWidth < 700;
        final summaryCards = _buildSummaryCardsList(useColumnLayout, context);

        return useColumnLayout
            ? Column(children: summaryCards)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildSummaryCardsList(
                  useColumnLayout,
                  context,
                ).map((card) => Expanded(child: card)).toList(),
              );
      },
    );
  }

  List<Widget> _buildSummaryCardsList(
    bool useColumnLayout,
    BuildContext context,
  ) {
    double currentMonthExpenses = 0.0;
    double currentMonthIncome = 0.0;
    double currentMonthDeductibleExpenses = 0.0; 

    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    if (!isLoading && error == null) {
      for (var expense in expenses) {
        try {
          final expenseDate = DateTime.parse(expense.date); 
          if (expenseDate.month == currentMonth &&
              expenseDate.year == currentYear) {
            currentMonthExpenses += expense.amount;
            if (expense.isDeductible) { 
              currentMonthDeductibleExpenses += expense.amount;
            }
          }
        } catch (e) {
          print('Error parsing expense date: ${expense.date} or processing deductible: $e');

        }
      }
    }

    double currentMonthIncomes = 0.0;
    if (!isLoading && error == null) {
      for (var income in incomes) {
        if (income.date != null &&
            DateTime.parse(income.date).month == currentMonth &&
            DateTime.parse(income.date).year == currentYear) {
          currentMonthIncomes += income.amount;
        }
      }
    }

    final cardData = [
      {
        'title': 'Income',
        'amount': 'RM ${currentMonthIncome.toStringAsFixed(2)}',
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF34A853), 
        'progress': 0.0,
        'subtitle': 'For ${DateFormat.MMMM().format(now)}',
        'gradient': LinearGradient(
          colors: [Colors.white, const Color(0xFF34A853).withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )

      },
      {
        'title': 'Monthly Expenses',
        'amount': 'RM ${currentMonthExpenses.toStringAsFixed(2)}',
        'icon': Icons.receipt_long_outlined,
        'color': const Color(0xFF3776A1), 
        'progress': 0.0, 
        'subtitle': 'For ${DateFormat.MMMM().format(now)}',
        'gradient': LinearGradient(
          colors: [Colors.white, const Color(0xFF89CFF1).withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'Deductions',
        'amount': 'RM ${currentMonthDeductibleExpenses.toStringAsFixed(2)}', 
        'icon': Icons.savings_outlined,
        'color': const Color(0xFF5293B8), 
        'progress': 0.0,
        'subtitle': currentMonthDeductibleExpenses > 0 
            ? 'Deductible for ${DateFormat.MMMM().format(now)}' 
            : 'No deductions for ${DateFormat.MMMM().format(now)}', 
        'gradient': LinearGradient(
          colors: [Colors.white, const Color(0xFF003A6B).withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
    ];

    return cardData.map((data) {
      final card = _buildSummaryCard(
        data['title'] as String,
        data['amount'] as String,
        data['icon'] as IconData,
        data['color'] as Color,
        data['progress'] as double,
        data['subtitle'] as String,
        data['gradient'] as LinearGradient,
        context,
      );
      return useColumnLayout
          ? Padding(padding: const EdgeInsets.only(bottom: 16.0), child: card)
          : card;
    }).toList();
  }

  Widget _buildSummaryCard(
    String title,
    String amount,
    IconData icon,
    Color color,
    double progress,
    String subtitle,
    LinearGradient gradient,
    BuildContext context,
  ) {
    Widget cardContent = Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: gradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: title == 'Monthly Expenses'
                      ? const Color(0xFF3776A1)
                      : title == 'Income'
                          ? const Color(0xFF34A853)
                          : title == 'Deductions'
                              ? const Color(0xFF5293B8)
                              : const Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
              ),
              if (progress > 0) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (title == 'Monthly Expenses') {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => 
                const PlaceholderScreen(title: 'Monthly Expenses Summary'), // Navigate to PlaceholderScreen
            ),
          ).then((_) => onReloadExpenses()); // Still call onReloadExpenses if needed, or remove if not applicable

        },
        borderRadius: BorderRadius.circular(12), // Match Card's shape
        child: cardContent,
      );
    } else if (title == 'Income') {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const IncomeEntryScreen(),
            ),
          ).then((_) => onReloadIncomes());

        },
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      );
    } else if (title == 'Deductions') {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const PlaceholderScreen(title: 'Deductions Summary'),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      );
    }

    return cardContent;
  }
}