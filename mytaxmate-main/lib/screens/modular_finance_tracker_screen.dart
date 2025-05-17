import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/expense.dart';
import '../models/income.dart'; // Add this import
import '../services/expense_service.dart';
import 'upload_options_screen.dart';
import 'tax_news_screen.dart';
import 'placeholder_screen.dart';
import 'chat_assistant_screen.dart';
import 'reports_screen.dart'; // Import the ReportsScreen
import '../services/income_service.dart'; // Add this import

// Import the new widget components
import '../widgets/finance_tracker/navigation_rail.dart';
import '../widgets/finance_tracker/bottom_navigation_bar.dart';
import '../widgets/finance_tracker/summary_cards.dart';
import '../widgets/finance_tracker/section_header.dart';
import '../widgets/finance_tracker/expenses_table.dart';
import '../widgets/finance_tracker/expense_categories.dart';
import '../widgets/finance_tracker/smart_assistant.dart';
import 'income_entry_screen.dart';
import '../widgets/finance_tracker/income_table.dart';

class ModularFinanceTrackerScreen extends StatefulWidget {
  const ModularFinanceTrackerScreen({super.key});

  @override
  State<ModularFinanceTrackerScreen> createState() =>
      _ModularFinanceTrackerScreenState();
}

class _ModularFinanceTrackerScreenState
    extends State<ModularFinanceTrackerScreen> {
  int _selectedIndex = 0;
  final ExpenseService _expenseService = ExpenseService();
  List<Expense> _expenses = [];
  bool _isLoadingExpenses = false; // Renamed for clarity
  String? _errorExpenses; // Renamed for clarity

  // Add state for Incomes
  final IncomeService _incomeService = IncomeService();
  List<Income> _incomes = [];
  bool _isLoadingIncomes = false;
  String? _errorIncomes;

  // Scroll controller and app bar opacity state
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    _loadIncomes(); // Call to load incomes

    // Add listener to scroll controller to update app bar opacity
    _scrollController.addListener(_updateAppBarOpacity);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateAppBarOpacity);
    _scrollController.dispose();
    // Dispose other controllers if any
    super.dispose();
  }

  void _updateAppBarOpacity() {
    final scrollOffset = _scrollController.offset;
    // Define the scroll range where opacity changes (0 to 150 pixels of scrolling)
    const maxOffset = 150.0;

    if (scrollOffset < maxOffset) {
      // Calculate opacity based on scroll position (1.0 at top, 0.0 at maxOffset)
      setState(() {
        _appBarOpacity = 1.0 - (scrollOffset / maxOffset).clamp(0.0, 0.85);
      });
    } else if (_appBarOpacity != 0.15) {
      // Set a minimum opacity value to keep a slight hint of the app bar
      setState(() {
        _appBarOpacity = 0.15;
      });
    }
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoadingExpenses = true;
      _errorExpenses = null;
    });

    try {
      final expenses = await _expenseService.getRecentExpenses();
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _isLoadingExpenses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorExpenses = 'Failed to load expenses: ${e.toString()}';
          _isLoadingExpenses = false;
        });
      }
    }
  }

  // Method to load incomes
  Future<void> _loadIncomes() async {
    setState(() {
      _isLoadingIncomes = true;
      _errorIncomes = null;
    });

    try {
      final incomes = await _incomeService.getRecentIncomes();
      if (mounted) {
        // Sort incomes by date (descending) after fetching
        incomes.sort((a, b) {
          DateTime? dateA, dateB;
          try {
            if (a.date.isNotEmpty) dateA = DateTime.parse(a.date);
            if (b.date.isNotEmpty) dateB = DateTime.parse(b.date);
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          } catch (e) {
            if (dateA == null && dateB != null) return 1;
            if (dateA != null && dateB == null) return -1;
            return 0;
          }
        });
        setState(() {
          _incomes = incomes;
          _isLoadingIncomes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorIncomes = 'Failed to load incomes: ${e.toString()}';
          _isLoadingIncomes = false;
        });
      }
    }
  }

  Future<void> fetchData({String? tableName, String? input}) async {
    if (tableName == null || tableName.isEmpty) {
      if (mounted) {
        setState(() {
          _errorExpenses =
              'Table name not provided for fetchData.'; // Assuming this was for expenses
          _isLoadingExpenses = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        // Decide which loader to set based on tableName or a new parameter
        if (tableName == 'expenses') _isLoadingExpenses = true;
        if (tableName == 'incomes') _isLoadingIncomes = true;
        _errorExpenses = null;
        _errorIncomes = null;
      });
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from(tableName).select().limit(10);

      if (tableName == 'expenses') {
        final List<Expense> fetchedExpenses =
            (response).map((data) => Expense.fromJson(data)).toList();
        if (mounted) {
          setState(() {
            _expenses = fetchedExpenses;
          });
        }
      } else if (tableName == 'incomes') {
        // Handle fetching incomes if needed via this generic method
        final List<Income> fetchedIncomes =
            (response).map((data) => Income.fromJson(data)).toList();
        if (mounted) {
          // Sort incomes by date (descending) after fetching
          fetchedIncomes.sort((a, b) {
            DateTime? dateA, dateB;
            try {
              if (a.date.isNotEmpty) dateA = DateTime.parse(a.date);
              if (b.date.isNotEmpty) dateB = DateTime.parse(b.date);
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA);
            } catch (e) {
              if (dateA == null && dateB != null) return 1;
              if (dateA != null && dateB == null) return -1;
              return 0;
            }
          });
          setState(() {
            _incomes = fetchedIncomes;
          });
        }
      }

      // Sort expenses by date (descending) after fetching - This might be redundant if _loadExpenses does it
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
          // Fallback: attempt to sort invalid ones consistently to the end
          if (dateA == null && dateB != null) return 1;
          if (dateA != null && dateB == null) return -1;
          return 0; // Both invalid or other error, keep original relative order
        }
      });

      if (mounted) {
        setState(() {
          // Decide which loader to set based on tableName or a new parameter
          if (tableName == 'expenses') _isLoadingExpenses = false;
          if (tableName == 'incomes') _isLoadingIncomes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (tableName == 'expenses') {
            _errorExpenses =
                'Failed to fetch data from $tableName: ${e.toString()}';
            _isLoadingExpenses = false;
          } else if (tableName == 'incomes') {
            _errorIncomes =
                'Failed to fetch data from $tableName: ${e.toString()}';
            _isLoadingIncomes = false;
          }
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

  // Method to view or download income documents
  Future<void> _viewOrDownloadIncomeDocument(
    String storagePath, {
    bool download = false,
  }) async {
    const String bucketName =
        'income-bucket'; // Ensure this is your income bucket
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
            SnackBar(content: Text('Could not open document. URL: $publicUrl')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting document URL: ${e.toString()}'),
          ),
        );
      }
    }
  }

  void _onNavigationItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    // Define the main content widget based on the selected index
    Widget mainContent;
    switch (_selectedIndex) {
      case 0: // Home
        mainContent = CustomScrollView(
          controller: _scrollController, // Use scroll controller for Home
          slivers: [
            if (isWideScreen)
              SliverAppBar(
                pinned: true,
                floating: false,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.white.withOpacity(_appBarOpacity),
                elevation: _appBarOpacity < 0.8 ? 4 * (1 - _appBarOpacity) : 0,
                shadowColor: Colors.black.withOpacity(0.1),
                titleSpacing: 24,
                title: Image.asset(
                  'assets/images/mytaxmate-logo.png',
                  height: 42,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(_appBarOpacity),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
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
                            color: const Color(0xFF003A6B).withOpacity(0.2),
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
                  // Summary Cards
                  SummaryCards(
                    expenses: _expenses,
                    incomes: _incomes,
                    isLoading: _isLoadingExpenses || _isLoadingIncomes,
                    error: _errorExpenses ?? _errorIncomes,
                    onReload: () {
                      _loadExpenses();
                      _loadIncomes();
                    },
                  ),
                  const SizedBox(height: 24),

                  // Recent Expenses Section
                  SectionHeader(
                    title: 'Recent Expenses',
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_errorExpenses != null)
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
                                color: const Color(0xFF003A6B).withOpacity(0.2),
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
                                      (context) => const ExpenseEntryScreen(),
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
                  const SizedBox(height: 16),

                  // Expenses Table
                  ExpensesTable(
                    expenses: _expenses,
                    isLoading: _isLoadingExpenses,
                    error: _errorExpenses,
                    onReload: _loadExpenses,
                    onViewReceipt: _viewOrDownloadReceipt,
                  ),
                  const SizedBox(height: 24),

                  // Recent Incomes Section
                  SectionHeader(
                    title: 'Recent Incomes',
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_errorIncomes != null)
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadIncomes,
                            tooltip: 'Retry loading incomes',
                          ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A6E3A), Color(0xFF0D4D2E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF34A853).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_card_outlined, size: 18),
                            label: const Text('Add Income'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const IncomeEntryScreen(),
                                ),
                              ).then((_) => _loadIncomes());
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

                  // Income Table
                  IncomeTable(
                    incomes: _incomes,
                    isLoading: _isLoadingIncomes,
                    error: _errorIncomes,
                    onReload: _loadIncomes,
                    onViewDocument: _viewOrDownloadIncomeDocument,
                  ),
                  const SizedBox(height: 24),

                  // Categories and Smart Assistant
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool useColumnLayout = constraints.maxWidth < 800;
                      return useColumnLayout
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ExpenseCategories(
                                expenses: _expenses,
                                isLoading: _isLoadingExpenses,
                                error: _errorExpenses,
                              ),
                              const SizedBox(height: 24),
                              const SmartAssistant(),
                            ],
                          )
                          : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: ExpenseCategories(
                                  expenses: _expenses,
                                  isLoading: _isLoadingExpenses,
                                  error: _errorExpenses,
                                ),
                              ),
                              const SizedBox(width: 24),
                              const Expanded(flex: 3, child: SmartAssistant()),
                            ],
                          );
                    },
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        );
        break;
      case 1: // Reports
        mainContent = const ReportsScreen();
        break;
      case 2: // Tax News
        mainContent = const TaxNewsScreen();
        break;
      default:
        mainContent = const Center(child: Text('Unknown navigation index'));
    }

    return Scaffold(
      appBar:
          isWideScreen
              ? null // No AppBar on wide screens, handled by SliverAppBar
              : AppBar(
                title: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Image.asset(
                    'assets/images/mytaxmate-logo.png',
                    height: 36,
                  ),
                ),
                backgroundColor: Colors.white.withOpacity(_appBarOpacity),
                elevation: _appBarOpacity < 0.8 ? 4 * (1 - _appBarOpacity) : 0,
                shadowColor: Colors.black.withOpacity(0.1),
                flexibleSpace: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(_appBarOpacity),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_none_outlined,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(_appBarOpacity),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const TaxNewsScreen(),
                        ),
                      );
                    },
                    tooltip: 'Tax Relief News',
                  ),
                  const SizedBox(width: 8),
                ],
              ),
      body: Row(
        children: [
          if (isWideScreen)
            FinanceTrackerNavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onNavigationItemTapped,
              onLogout: () {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
          Expanded(
            // Display the selected main content widget
            child: mainContent,
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
            ChatAssistantScreen.show(context);
          },
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          tooltip: 'Chat Assistant',
          child: const Icon(Icons.chat_bubble_outline),
        ),
      ),
      bottomNavigationBar:
          isWideScreen
              ? null // No BottomNavigationBar on wide screens
              : FinanceTrackerBottomNavigationBar(
                selectedIndex: _selectedIndex,
                onTap: _onNavigationItemTapped,
                onLogout: () {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                },
              ),
    );
  }
}
