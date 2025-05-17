import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../main.dart'; // Import to access AppGradients
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'upload_options_screen.dart';
import 'tax_news_screen.dart';
import 'placeholder_screen.dart'; // Added import for PlaceholderScreen
import 'chat_assistant_screen.dart'; // Add this import

class FinanceTrackerScreen extends StatefulWidget {
  const FinanceTrackerScreen({super.key});

  @override
  State<FinanceTrackerScreen> createState() => _FinanceTrackerScreenState();
}

class _FinanceTrackerScreenState extends State<FinanceTrackerScreen> {
  int _selectedIndex = 0;
  final ExpenseService _expenseService = ExpenseService();
  List<Expense> _expenses = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final expenses = await _expenseService.getRecentExpenses();
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load expenses: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // New function to receive input and fetch data from Supabase
  Future<void> fetchData({String? tableName, String? input}) async {
    if (tableName == null || tableName.isEmpty) {
      //print("fetchData error: tableName cannot be null or empty.");
      if (mounted) {
        setState(() {
          _error = 'Table name not provided for fetchData.';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    // //print("fetchData called for table: $tableName with input: $input");

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from(tableName)
          .select()
          // .order('created_at', ascending: false) // Removed: Sorting will be done in Dart by 'date'
          .limit(10);

      // //print('Fetched data from $tableName:');
      if (tableName == 'expenses') {
        final List<Expense> fetchedExpenses =
            (response).map((data) => Expense.fromJson(data)).toList();
        if (mounted) {
          setState(() {
            _expenses = fetchedExpenses;
          });
        }
        // } else {
        //   // Handle other table types if necessary or log them
        //   // for (var row in response) {
        //   //   print(row);
        //   // }
      }

      // Sort expenses by date (descending) after fetching
      _expenses.sort((a, b) {
        DateTime? dateA, dateB;
        try {
          // Ensure date strings are not null or empty before parsing
          if (a.date.isNotEmpty) {
            dateA = DateTime.parse(a.date);
          }
          if (b.date.isNotEmpty) {
            dateB = DateTime.parse(b.date);
          }

          // Handle cases where one or both dates are unparsable/null
          if (dateA == null && dateB == null) {
            return 0; // Both invalid, keep order
          }
          if (dateA == null) {
            return 1; // A is invalid, sort A after B (ascending for invalid)
          }
          if (dateB == null) {
            return -1; // B is invalid, sort B after A (ascending for invalid)
          }

          return dateB.compareTo(dateA); // Descending order for valid dates
        } catch (e) {
          //print('Error parsing date during sort (a: "${a.date}", b: "${b.date}"): $e');
          // Fallback: attempt to sort invalid ones consistently to the end
          if (dateA == null && dateB != null) return 1;
          if (dateA != null && dateB == null) return -1;
          return 0; // Both invalid or other error, keep original relative order
        }
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      //print('Error fetching data from $tableName: ${e.toString()}');
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch data from $tableName: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _viewOrDownloadReceipt(
    String storagePath, {
    bool download = false,
  }) async {
    const String bucketName = 'receipts-bucket';
    try {
      final supabaseClient = Supabase.instance.client;
      final String publicUrl = supabaseClient.storage
          .from(bucketName)
          .getPublicUrl(storagePath);

      final Uri uri = Uri.parse(publicUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open receipt. URL: $publicUrl')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting receipt URL: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar:
          isWideScreen
              ? null
              : AppBar(
                title: const Text(
                  'MyTaxMate',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.white,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_none_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                ],
              ),
      body: Row(
        children: [
          if (isWideScreen) _buildNavigationRail(),
          Expanded(
            child:
                _selectedIndex == 3
                    ? const TaxNewsScreen()
                    : CustomScrollView(
                      slivers: [
                        if (isWideScreen)
                          SliverAppBar(
                            pinned: true,
                            floating: false,
                            automaticallyImplyLeading: false,
                            backgroundColor: Colors.white,
                            elevation: 0,
                            titleSpacing: 24,
                            title: const Text(
                              'MyTaxMate',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Color(0xFF202124),
                              ),
                            ),
                            actions: [
                              Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.blueGradient,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF003A6B,
                                        ).withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.download, size: 18),
                                    label: const Text('Download Report'),
                                    onPressed: () {
                                      // TODO: Implement Download Report
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.all(24.0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  bool useColumnLayout =
                                      constraints.maxWidth < 700;
                                  return useColumnLayout
                                      ? Column(
                                        children: _summaryCardsList(
                                          useColumnLayout,
                                        ),
                                      )
                                      : Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children:
                                            _summaryCardsList(useColumnLayout)
                                                .map(
                                                  (card) =>
                                                      Expanded(child: card),
                                                )
                                                .toList(),
                                      );
                                },
                              ),
                              const SizedBox(height: 24),
                              _buildSectionHeader(
                                'Recent Expenses',
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_error != null)
                                      IconButton(
                                        icon: const Icon(Icons.refresh),
                                        onPressed: _loadExpenses,
                                        tooltip: 'Retry loading expenses',
                                      ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.blueGradient,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF003A6B,
                                            ).withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.upload_file_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Add Record'),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      const ExpenseEntryScreen(), // Corrected class name if it was changed, ensure this is the correct screen
                                            ),
                                          ).then(
                                            (_) => _loadExpenses(),
                                          ); // Reload expenses after returning from upload
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
                              const SizedBox(height: 16),
                              _buildExpensesTable(),
                              const SizedBox(height: 24),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  bool useColumnLayout =
                                      constraints.maxWidth < 800;
                                  return useColumnLayout
                                      ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildExpenseCategories(),
                                          const SizedBox(height: 24),
                                          _buildSmartAssistant(),
                                        ],
                                      )
                                      : Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: _buildExpenseCategories(),
                                          ),
                                          const SizedBox(width: 24),
                                          Expanded(
                                            flex: 3,
                                            child: _buildSmartAssistant(),
                                          ),
                                        ],
                                      );
                                },
                              ),
                              const SizedBox(height: 24),
                            ]),
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.blueGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF003A6B).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            // Open Chat Assistant
            ChatAssistantScreen.show(context);
          },
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          tooltip: 'Chat Assistant',
          child: const Icon(Icons.chat_bubble_outline),
        ),
      ),
      bottomNavigationBar: isWideScreen ? null : _buildBottomNavigationBar(),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (int index) {
        setState(() {
          _selectedIndex = index;
          // Navigation is now handled in the build method based on _selectedIndex
        });
      },
      minWidth: 56.0,
      backgroundColor: Colors.white,
      elevation: 0,
      selectedIconTheme: IconThemeData(
        color: Theme.of(context).colorScheme.primary,
      ),
      selectedLabelTextStyle: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      unselectedIconTheme: IconThemeData(color: Colors.grey[600]),
      unselectedLabelTextStyle: TextStyle(color: Colors.grey[600]),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Container(
          height: 48,
          width: 48,
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
          child: const Icon(Icons.calculate, color: Colors.white, size: 24),
        ),
      ),
      destinations: const <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.inbox_outlined),
          selectedIcon: Icon(Icons.inbox),
          label: Text('Inbox'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: Text('Reports'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.article_outlined),
          selectedIcon: Icon(Icons.article),
          label: Text('Tax News'),
        ),
      ],
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_outlined),
                  onPressed: () {},
                  color: Colors.grey[600],
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {},
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 10),
                const CircleAvatar(
                  // TODO: Replace with user profile picture or initials
                  radius: 18,
                  // TODO: Replace with user profile picture or initials
                  child: Text("P"),
                ),
              ],
            ),
          ),
        ),
      ),
      labelType: NavigationRailLabelType.selected,
    );
  }

  BottomNavigationBar? _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (int index) {
        setState(() {
          _selectedIndex = index;
          // Navigation is now handled in the build method based on _selectedIndex
        });
      },
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inbox_outlined),
          activeIcon: Icon(Icons.inbox),
          label: 'Inbox',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Reports',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.article_outlined),
          activeIcon: Icon(Icons.article),
          label: 'Tax News',
        ),
      ],
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF3776A1),
      unselectedItemColor: Colors.grey[600],
      elevation: 8,
      backgroundColor: Colors.white,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
    );
  }

  List<Widget> _summaryCardsList(bool useColumnLayout) {
    // Calculate total expenses for the current month
    double currentMonthExpenses = 0.0;
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    if (!_isLoading && _error == null) {
      for (var expense in _expenses) {
        if (DateTime.parse(expense.date).month == currentMonth &&
            DateTime.parse(expense.date).year == currentYear) {
          currentMonthExpenses += expense.amount;
        }
      }
    }

    final cardData = [
      {
        'title': 'Income',
        'amount': 'RM 0.00', // Placeholder for now
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF34A853), // Using green from our palette
        'progress': 0.0,
        'subtitle': 'Target not set',
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
        'title': 'Deductions',
        'amount': 'RM 0.00', // Placeholder for now
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
          ).then((_) => _loadExpenses()); // Reload expenses after returning
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
              builder:
                  (context) => const PlaceholderScreen(title: 'Income Summary'),
            ),
          );
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

  Widget _buildSectionHeader(String title, [Widget? action]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppGradients.blueGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202124),
                ),
              ),
            ],
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildExpensesTable() {
    final bool isMobileView = MediaQuery.of(context).size.width < 600;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF3776A1)),
        ),
      );
    }

    if (_error != null) {
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
                _error!,
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
                  onPressed: _loadExpenses,
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

    if (_expenses.isEmpty) {
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
                    ).then((_) => _loadExpenses());
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
        itemCount: _expenses.length,
        itemBuilder: (context, index) {
          final expense = _expenses[index];
          return _buildMobileExpenseListItem(expense);
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
                      _expenses.map((expense) {
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
                                            () => _viewOrDownloadReceipt(
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
                                            () => _viewOrDownloadReceipt(
                                              expense.receiptStoragePath!,
                                              download: true,
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
  Widget _buildMobileExpenseListItem(Expense expense) {
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
                                () => _viewOrDownloadReceipt(
                                  expense.receiptStoragePath!,
                                ),
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
                  _viewOrDownloadReceipt(expense.receiptStoragePath!);
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
                  _viewOrDownloadReceipt(
                    expense.receiptStoragePath!,
                    download: true,
                  );
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

  Widget _buildExpenseCategories() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error loading expenses: $_error'));
    }
    if (_expenses.isEmpty) {
      return const Center(child: Text('No expenses recorded yet.'));
    }

    // Group expenses by category
    Map<String, List<Expense>> expensesByCategory = {};
    for (var expense in _expenses) {
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
          // Use Flexible with Expanded for the title text to make it wrap or truncate properly
          Expanded(
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
          // Use a constrained container for the amount
          Expanded(
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

  Widget _buildSmartAssistant() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFF6EB1D6).withOpacity(0.1),
              const Color(0xFF89CFF1).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppGradients.lightBlueGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3776A1).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "Smart Assistant",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF202124),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildAlertCard(
              icon: Icons.insights_rounded,
              title: "Expense Insights",
              message:
                  "This is a placeholder message for an insight from the smart assistant. It might offer tips or observations.",
              backgroundColor: const Color(0xFF89CFF1).withOpacity(0.1),
              iconColor: const Color(0xFF1B5886),
              borderColor: const Color(0xFF89CFF1).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            _buildAlertCard(
              icon: Icons.lightbulb_outlined,
              title: "Tax Saving Recommendation",
              message:
                  "Another placeholder insight. This could be a reminder or a suggestion for optimizing your finances.",
              backgroundColor: const Color(0xFF003A6B).withOpacity(0.05),
              iconColor: const Color(0xFF3776A1),
              borderColor: const Color(0xFF003A6B).withOpacity(0.2),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  // TODO: Implement "See All Insights"
                },
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text(
                  'See All Insights',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required IconData icon,
    required String title,
    required String message,
    required Color backgroundColor,
    required Color iconColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF5F6368),
                    height: 1.4,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
