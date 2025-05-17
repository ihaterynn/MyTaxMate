import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'upload_options_screen.dart';
import 'tax_news_screen.dart';
import 'placeholder_screen.dart';
import 'chat_assistant_screen.dart';
import 'reports_screen.dart'; // Import the ReportsScreen

// Import the new widget components
import '../widgets/finance_tracker/navigation_rail.dart';
import '../widgets/finance_tracker/bottom_navigation_bar.dart';
import '../widgets/finance_tracker/summary_cards.dart';
import '../widgets/finance_tracker/section_header.dart';
import '../widgets/finance_tracker/expenses_table.dart';
import '../widgets/finance_tracker/expense_categories.dart';
import '../widgets/finance_tracker/smart_assistant.dart';

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
  bool _isLoading = false;
  String? _error;

  // Scroll controller and app bar opacity state for the Home content
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    // Load expenses initially when the screen is created
    _loadExpenses();

    // Add listener to scroll controller ONLY if we are on the home screen initially
    // This listener is specifically for the Home content's SliverAppBar opacity effect.
    if (_selectedIndex == 0) {
      _scrollController.addListener(_updateAppBarOpacity);
    }
  }

  @override
  void dispose() {
    // Clean up the scroll controller listener
    _scrollController.removeListener(_updateAppBarOpacity);
    _scrollController.dispose();
    super.dispose();
  }

  // Callback function for navigation item selection
  void _onNavigationItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Re-attach or remove the scroll listener based on the selected index
      if (_selectedIndex == 0) {
        // Attach listener only when Home is selected
        if (!_scrollController.hasListeners) {
          _scrollController.addListener(_updateAppBarOpacity);
          // Immediately update opacity based on current scroll position if needed
          _updateAppBarOpacity();
        }
      } else {
        // Remove listener when not on the Home screen
        if (_scrollController.hasListeners) {
          _scrollController.removeListener(_updateAppBarOpacity);
          // Optionally reset opacity when leaving the Home screen
          _appBarOpacity = 1.0;
        }
      }
    });
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
      _isLoading = true;
      _error = null;
    });

    try {
      final expenses = await _expenseService.getRecentExpenses();
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _isLoading = false;
          // Sort expenses by date (descending) after fetching
          _expenses.sort((a, b) {
            DateTime? dateA, dateB;
            try {
              if (a.date.isNotEmpty) dateA = DateTime.parse(a.date);
              if (b.date.isNotEmpty) dateB = DateTime.parse(b.date);
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA);
            } catch (e) {
              return 0; // Keep original order if dates are invalid
            }
          });
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

  // This function seems redundant with _loadExpenses if it always limits to 10
  // and is only used for expenses. Consider removing or refactoring.
  Future<void> fetchData({String? tableName, String? input}) async {
    // Placeholder - likely not needed if _loadExpenses is the primary way
    // to get initial expense data.
    print("fetchData called, but _loadExpenses is primary.");
    await _loadExpenses(); // Just delegate to _loadExpenses for now
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
                          // TODO: Implement Download Report - Maybe open a dialog for options?
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
                    isLoading: _isLoading,
                    error: _error,
                    onReload: _loadExpenses, // Pass reload function
                  ),
                  const SizedBox(height: 24),

                  // Recent Expenses Section
                  SectionHeader(
                    title: 'Recent Expenses',
                    action: Row(
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
                              ).then(
                                (_) => _loadExpenses(),
                              ); // Reload after adding
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
                    isLoading: _isLoading,
                    error: _error,
                    onReload: _loadExpenses, // Pass reload function
                    onViewReceipt:
                        _viewOrDownloadReceipt, // Pass view/download function
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
                                isLoading: _isLoading,
                                error: _error,
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
                                  isLoading: _isLoading,
                                  error: _error,
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
        // Note: ReportsScreen manages its own scrolling and loading internally
        mainContent = const ReportsScreen();
        break;
      case 2: // Tax News
        // Note: TaxNewsScreen manages its own scrolling and loading internally
        mainContent = const TaxNewsScreen();
        break;
      default:
        // Fallback to Home or an error screen
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
                // Use the calculated opacity for the narrow screen AppBar as well
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
                      color: Theme.of(context).colorScheme.primary.withOpacity(
                        1.0 - _appBarOpacity,
                      ), // Adjust icon opacity
                    ),
                    onPressed: () {
                      // Example: Navigate to Tax News screen via a route if it's a separate screen
                      // If TaxNewsScreen is only shown via the bottom bar/rail, this button might not be needed here
                      // or could show a different notification UI.
                      // For consistency with the rail/bar, we'll navigate to the Tax News using the index
                      _onNavigationItemTapped(2); // Select Tax News index
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
              onDestinationSelected:
                  _onNavigationItemTapped, // Use the renamed callback
              onLogout: () async {
                // Sign out using Supabase
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
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
                onTap: _onNavigationItemTapped, // Use the renamed callback
                onLogout: () async {
                  // Sign out using Supabase
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
              ),
    );
  }
}
