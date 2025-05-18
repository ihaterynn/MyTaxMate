import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../screens/income_entry_screen.dart';
import '../../screens/placeholder_screen.dart';
import '../../screens/upload_options_screen.dart';
import '../../models/expense.dart';
import '../../models/income.dart';

class SummaryCards extends StatelessWidget {
  final List<Expense> expenses;
  final List<Income> incomes;
  final bool isLoading;
  final String? error;
  final VoidCallback onReload;

  const SummaryCards({
    Key? key,
    required this.expenses,
    required this.incomes,
    required this.isLoading,
    this.error,
    required this.onReload,
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
              children:
                  summaryCards.map((card) => Expanded(child: card)).toList(),
            );
      },
    );
  }

  List<Widget> _buildSummaryCardsList(
    bool useColumnLayout,
    BuildContext context,
  ) {
    // Calculate total expenses for the current month
    double currentMonthExpenses = 0.0;
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    if (!isLoading && error == null) {
      for (var expense in expenses) {
        if (DateTime.parse(expense.date).month == currentMonth &&
            DateTime.parse(expense.date).year == currentYear) {
          currentMonthExpenses += expense.amount;
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
        'amount':
            'RM ${currentMonthIncomes.toStringAsFixed(2)}', // Placeholder for now
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF34A853), // Using green from our palette
        'progress': 0.0,
        'subtitle': 'For ${DateFormat.MMMM().format(now)}',
        'gradient': LinearGradient(
          colors: [Colors.white, const Color(0xFF34A853).withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'Monthly Expenses',
        'amount': 'RM ${currentMonthExpenses.toStringAsFixed(2)}',
        'icon': Icons.receipt_long_outlined,
        'color': const Color(0xFF3776A1), // Medium blue from our palette
        'progress': 0.0, // Placeholder, can be budget utilization
        'subtitle': 'For ${DateFormat.MMMM().format(now)}',
        'gradient': LinearGradient(
          colors: [Colors.white, const Color(0xFF89CFF1).withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'Tax Deductions',
        'amount': 'RM 346.34', // Placeholder for now
        'icon': Icons.savings_outlined,
        'color': const Color(0xFF5293B8), // Blue from our palette
        'progress': 0.0,
        'subtitle': 'Estimated savings not set',
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
                  color:
                      title == 'Monthly Expenses'
                          ? const Color(0xFF3776A1)
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

    // Wrap cards with InkWell for touch interactions
    if (title == 'Monthly Expenses') {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ExpenseEntryScreen()),
          ).then((_) => onReload()); // Reload expenses after returning
        },
        borderRadius: BorderRadius.circular(12), // Match Card's shape
        child: cardContent,
      );
    } else if (title == 'Income') {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IncomeEntryScreen()),
          ).then((_) => onReload()); // Reload expenses after returning
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
              builder:
                  (context) =>
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
