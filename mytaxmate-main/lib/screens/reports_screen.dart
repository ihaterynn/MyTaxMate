import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'dart:math' as math; // Import math for log and pow in maxY calculation

import '../main.dart'; // To access AppGradients (optional, for consistent styling)
import '../widgets/finance_tracker/section_header.dart'; // Reusing the header widget
import '../models/expense.dart';
import '../models/income.dart'; // Uncommented import for Income model
import 'dart:io'; // Ensure this is imported if not already
import '../utils/pdf_generator.dart';

// Place the extension here, after imports and before class definitions
extension on num {
  double log({double base = 10}) => math.log(this) / math.log(base);
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Data structures for monthly reports (month index 1-12, amount)
  Map<int, double> monthlyIncomeTotals = {};
  Map<int, double> monthlyExpensesTotals = {};
  bool isLoading = false;
  String? error;
  int _selectedYear = DateTime.now().year; // Default to current year
  List<int> availableYears = []; // To populate year dropdown
  bool _isGeneratingYearlyPdf = false;

  @override
  void initState() {
    super.initState();
    _initializeAvailableYears();
    _loadReportData();
  }

  // Determine available years based on current year and a few past years
  void _initializeAvailableYears() {
    final currentYear = DateTime.now().year;
    availableYears = List.generate(
      5,
      (index) => currentYear - index,
    ); // Last 5 years
  }

  Future<void> _loadReportData() async {
    setState(() {
      isLoading = true;
      error = null;
      // Reset data before loading
      monthlyIncomeTotals = {};
      monthlyExpensesTotals = {};
    });

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        error = 'User not authenticated.';
        isLoading = false;
        // Ensure default data is present even if not authenticated
        _populateDefaultMonthlyTotals();
      });
      return;
    }

    try {
      // Fetch Expenses for the selected year
      final expensesResponse = await _supabase
          .from('expenses') // Assumes your expense table is named 'expenses'
          .select('date, amount') // Select only necessary columns
          .eq('user_id', userId)
          // Filter by date within the selected year
          .gte('date', '$_selectedYear-01-01')
          .lte('date', '$_selectedYear-12-31');

      // Process expenses
      if (expensesResponse.isNotEmpty) {
        for (var expenseJson in expensesResponse) {
          try {
            final date = DateTime.parse(expenseJson['date']);
            final amount = (expenseJson['amount'] as num).toDouble();
            final month = date.month;
            monthlyExpensesTotals.update(
              month,
              (value) => value + amount,
              ifAbsent: () => amount,
            );
          } catch (e) {
            print('Error processing expense data: $e');
          }
        }
      }

      // Fetch Income for the selected year from the 'incomes' table
      final incomeResponse = await _supabase
          .from('incomes') // <-- Corrected table name here
          .select('date, amount')
          .eq('user_id', userId)
          .gte('date', '$_selectedYear-01-01')
          .lte('date', '$_selectedYear-12-31');

      // Process income
      if (incomeResponse.isNotEmpty) {
        for (var incomeJson in incomeResponse) {
          try {
            final date = DateTime.parse(incomeJson['date']);
            final amount = (incomeJson['amount'] as num).toDouble();
            final month = date.month;
            monthlyIncomeTotals.update(
              month,
              (value) => value + amount,
              ifAbsent: () => amount,
            );
          } catch (e) {
            print('Error processing income data: $e');
          }
        }
      }

      // Ensure all 12 months are present, even if the total is 0
      _populateDefaultMonthlyTotals();

      // Sort the data by month
      monthlyIncomeTotals = Map.fromEntries(
        monthlyIncomeTotals.entries.toList()
          ..sort((e1, e2) => e1.key.compareTo(e2.key)),
      );
      monthlyExpensesTotals = Map.fromEntries(
        monthlyExpensesTotals.entries.toList()
          ..sort((e1, e2) => e1.key.compareTo(e2.key)),
      );
    } catch (e) {
      setState(() {
        error = 'Failed to load report data: ${e.toString()}';
        print('Supabase fetch error: $e'); // Print error for debugging
        // Populate with default values on error so charts can still display
        _populateDefaultMonthlyTotals();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // New helper function to populate monthly totals with 0.0 for all months
  void _populateDefaultMonthlyTotals() {
    for (int i = 1; i <= 12; i++) {
      monthlyIncomeTotals.putIfAbsent(i, () => 0.0);
      monthlyExpensesTotals.putIfAbsent(i, () => 0.0);
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> fetchIncomeAndExpensesForYear(
    int year,
  ) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return {'incomes': [], 'expenses': []};

    // Fetch incomes
    final incomes = await supabase
        .from('incomes')
        .select()
        .eq('user_id', userId)
        .gte('date', '$_selectedYear-01-01')
        .lte('date', '$_selectedYear-12-31');

    // Fetch expenses
    final expenses = await supabase
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .gte('date', '$_selectedYear-01-01')
        .lte('date', '$_selectedYear-12-31');

    return {
      'incomes': List<Map<String, dynamic>>.from(incomes),
      'expenses': List<Map<String, dynamic>>.from(expenses),
    };
  }

  Future<void> _generateYearlyIncomeStatement() async {
    if (!mounted) return;
    setState(() {
      _isGeneratingYearlyPdf = true;
    });
    try {
      final data = await fetchIncomeAndExpensesForYear(_selectedYear);
      await generateIncomeStatementPdf(
        context: context,
        period: 'For the Year Ended $_selectedYear',
        incomes: data['incomes']!,
        expenses: data['expenses']!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Yearly Income Statement PDF generated and opened."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating PDF statement: \\${e.toString()}"),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingYearlyPdf = false;
        });
      }
    }
  }

  // Helper to get month short name for chart labels
  String getMonthShortName(int month) {
    return DateFormat.MMM().format(DateTime(DateTime.now().year, month));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Financial Reports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF202124), // Use color from your theme
          ),
        ),
        elevation: 0,
        actions: [
          // Year Selection Dropdown
          DropdownButton<int>(
            value: _selectedYear,
            icon: const Icon(
              Icons.calendar_today_outlined,
              color: Color(0xFF3776A1),
            ),
            elevation: 16,
            style: const TextStyle(color: Color(0xFF202124), fontSize: 16),
            underline: Container(), // Remove underline
            onChanged: (int? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedYear = newValue;
                });
                _loadReportData(); // Reload data for the new year
              }
            },
            items:
                availableYears.map<DropdownMenuItem<int>>((int year) {
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
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
                        'Error Loading Reports',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReportData,
                        child: const Text('Retry'),
                      ),
                      // Display charts below the error if default data is populated
                      const SizedBox(height: 24),
                      SectionHeader(
                        title:
                            'Monthly Income ($_selectedYear) (Partial Data/Error)',
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildMonthlyLineChart(
                            monthlyIncomeTotals,
                            Colors.green,
                            'Income',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SectionHeader(
                        title:
                            'Monthly Expenses ($_selectedYear) (Partial Data/Error)',
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildMonthlyLineChart(
                            monthlyExpensesTotals,
                            Theme.of(context).colorScheme.primary,
                            'Expenses',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Component 1: Button generate income statement report by year
                    _buildReportButton(
                      context: context,
                      label: 'Generate Yearly Statement ($_selectedYear)',
                      icon: Icons.description_outlined,
                      onPressed: _generateYearlyIncomeStatement,
                    ),
                    const SizedBox(height: 20),

                    // Component 2: Classified income report by month (Line Chart)
                    SectionHeader(title: 'Monthly Income ($_selectedYear)'),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 16.0,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SizedBox(
                              width: constraints.maxWidth,
                              height: MediaQuery.of(context).size.height * 0.25,
                              child: _buildMonthlyLineChart(
                                monthlyIncomeTotals,
                                Colors.green,
                                'Income',
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Component 3: Classified expenses report by month (Line Chart)
                    SectionHeader(title: 'Monthly Expenses ($_selectedYear)'),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 16.0,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SizedBox(
                              width: constraints.maxWidth,
                              height: MediaQuery.of(context).size.height * 0.25,
                              child: _buildMonthlyLineChart(
                                monthlyExpensesTotals,
                                Theme.of(context).colorScheme.primary,
                                'Expenses',
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
    );
  }

  // Helper widget for building the report generation button
  Widget _buildReportButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.blueGradient, // Use your theme's gradient
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003A6B).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: isLoading ? null : onPressed, // Disable button while loading
        style: ElevatedButton.styleFrom(
          backgroundColor:
              Colors.transparent, // Make button transparent to show gradient
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0, // Remove default elevation
        ),
      ),
    );
  }

  // Helper widget to build the monthly line chart
  Widget _buildMonthlyLineChart(
    Map<int, double> data,
    Color lineColor,
    String title,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    // Sort data by month index (1-12) and create FlSpot list
    final List<FlSpot> spots =
        data.entries.map((entry) {
            // fl_chart uses double for x-values, so use month index directly
            return FlSpot(entry.key.toDouble(), entry.value);
          }).toList()
          ..sort(
            (a, b) => a.x.compareTo(b.x),
          ); // Ensure spots are sorted by month

    // Find max amount for setting chart height
    double maxY = 0;
    if (data.isNotEmpty) {
      // Calculate max amount from the data values
      maxY = data.values.fold(
        0.0,
        (max, amount) => amount > max ? amount : max,
      );
      // Add some padding to the max Y value for better visualization
      maxY = maxY * 1.2; // 20% padding
      if (maxY < 1000) maxY = 1000; // Ensure a minimum height for small values
    } else {
      maxY = 1000; // Default max height if no data
    }

    return AspectRatio(
      aspectRatio: 1.8, // Adjust aspect ratio for desired chart shape
      child: LineChart(
        LineChartData(
          // Enable touch interactions
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              // tooltipBgColor is likely not supported in your version
              // color is also reported as not defined for tooltip background
              // We will rely on the default tooltip appearance or set text style
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              // tooltipMargin is not supported as EdgeInsets
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final flSpot = touchedSpot;
                  final monthName = getMonthShortName(flSpot.x.toInt());
                  final amount = flSpot.y.toStringAsFixed(2);
                  return LineTooltipItem(
                    '$monthName: RM$amount',
                    // Apply text style here if tooltip background color can't be set
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
            // touchSpotCircleSize is likely not supported
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false, // Don't draw vertical grid lines
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[300]!, // Light grey horizontal lines
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: isMobile ? 28 : 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'RM${value.toInt()}',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: isMobile ? 10 : 12,
                    ),
                    textAlign: TextAlign.left,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  // Only show label for whole months (no decimals) and avoid duplicates
                  final monthIndex = value.toInt();
                  if (value == monthIndex.toDouble() &&
                      monthIndex >= 1 &&
                      monthIndex <= 12) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        getMonthShortName(monthIndex),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ), // Border around the chart
          ),
          minX: 1, // Start X axis at month 1
          maxX: 12, // End X axis at month 12
          minY: 0, // Start Y axis at 0
          maxY: maxY, // Set max Y based on data
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false, // Make the line straight
              color: lineColor,
              barWidth: 2, // Line thickness
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true), // Show dots on data points
              belowBarData: BarAreaData(
                show: false,
              ), // Don't fill area below the line
            ),
          ],
        ),
      ),
    );
  }
}
