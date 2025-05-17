import 'package:flutter/material.dart';
import 'dart:convert'; // For jsonEncode and jsonDecode
import 'package:http/http.dart' as http; // For making HTTP requests
import '../../main.dart'; // For AppGradients
import '../../services/expense_service.dart'; // Import your ExpenseService

enum InsightType {
  recommendation,
  warning,
  info,
}

class AiInsight {
  final String title;
  final String message;
  final IconData icon;
  final InsightType insightType;
  final Color backgroundColor;
  final Color iconColor;
  final Color borderColor;

  AiInsight({
    required this.title,
    required this.message,
    this.insightType = InsightType.info,
  })  : icon = _getIconForType(insightType),
        backgroundColor = _getBackgroundColorForType(insightType),
        iconColor = _getIconColorForType(insightType),
        borderColor = _getBorderColorForType(insightType);

  static IconData _getIconForType(InsightType type) {
    switch (type) {
      case InsightType.recommendation:
        return Icons.check_circle_outline;
      case InsightType.warning:
        return Icons.warning_amber_rounded;
      case InsightType.info:
      default:
        return Icons.lightbulb_outline;
    }
  }

  static Color _getBackgroundColorForType(InsightType type) {
    switch (type) {
      case InsightType.recommendation:
        return Colors.green.withOpacity(0.07);
      case InsightType.warning:
        return Colors.orange.withOpacity(0.07);
      case InsightType.info:
      default:
        return const Color(0xFFE3F2FD); // Light blue
    }
  }

  static Color _getIconColorForType(InsightType type) {
    switch (type) {
      case InsightType.recommendation:
        return Colors.green.shade700;
      case InsightType.warning:
        return Colors.orange.shade700;
      case InsightType.info:
      default:
        return const Color(0xFF1B5886); // Dark blue
    }
  }

  static Color _getBorderColorForType(InsightType type) {
    switch (type) {
      case InsightType.recommendation:
        return Colors.green.withOpacity(0.3);
      case InsightType.warning:
        return Colors.orange.withOpacity(0.3);
      case InsightType.info:
      default:
        return const Color(0xFFBBDEFB); // Lighter blue
    }
  }
}

class SmartAssistant extends StatefulWidget {
  const SmartAssistant({Key? key}) : super(key: key);

  @override
  _SmartAssistantState createState() => _SmartAssistantState();
}

class _SmartAssistantState extends State<SmartAssistant> {
  final ExpenseService _expenseService = ExpenseService();
  List<AiInsight> _insights = [];
  bool _isLoading = false;
  String? _errorMessage;

  final String _chatApiUrl = 'http://47.250.148.184:8002/chat';

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  InsightType _determineInsightType(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('warning') || lowerMessage.contains('due soon') || lowerMessage.contains('important') || lowerMessage.contains('alert')) {
      return InsightType.warning;
    }
    if (lowerMessage.contains('recommend') || lowerMessage.contains('consider') || lowerMessage.contains('tip:') || lowerMessage.contains('suggestion')) {
      return InsightType.recommendation;
    }
    return InsightType.info;
  }

  Future<void> _fetchInsights() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _insights = [];
    });

    try {
      List<Map<String, dynamic>> expenses = await _expenseService.getRecentExpensesAsJsonEncodable();

      final requestBody = {
        'query': 'Based on my recent expenses, provide a JSON list of 2-3 concise financial insights, spending patterns, and potential tax saving tips relevant to Malaysian context. Each item in the list should be a single, actionable sentence. Example: ["Your spending on X is high.", "Consider Y for tax relief."]',
        'expenses': expenses,
        'is_smart_assistant_query': true,
      };

      final response = await http.post(
        Uri.parse(_chatApiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final List<dynamic> decodedData = jsonDecode(utf8.decode(response.bodyBytes));

        if (decodedData is List) {
          _insights = decodedData.map<AiInsight>((item) {
            if (item is String) {
              final insightType = _determineInsightType(item);
              String title = "Smart Tip";
              if (insightType == InsightType.recommendation) title = "Recommendation";
              if (insightType == InsightType.warning) title = "Important Alert";

              return AiInsight(title: title, message: item, insightType: insightType);
            } else {
              return AiInsight(title: "Insight", message: "Received unexpected insight format.", insightType: InsightType.info);
            }
          }).toList();
          if (_insights.isEmpty) {
            _insights.add(AiInsight(title: "Smart Insight", message: "No specific insights generated this time. Check back later!", insightType: InsightType.info));
          }
        } else {
          _errorMessage = 'Received unexpected response format (not a list) from the assistant.';
        }
      } else {
        print('Failed to load insights: ${response.statusCode} ${response.body}');
        _errorMessage = 'Failed to load insights: ${response.statusCode}. Details: ${response.body.substring(0, (response.body.length > 100) ? 100 : response.body.length)}';
      }
    } catch (e) {
      print('Error fetching insights: $e');
      _errorMessage = 'An error occurred: ${e.toString()}. Check connection, server, or IP address in _chatApiUrl.';
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    Icons.insights, // Changed main icon for variety
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  "Smart Assistant",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF202124),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator(),
              ))
            else if (_errorMessage != null)
              _buildErrorCard(_errorMessage!)
            else if (_insights.isEmpty)
              _buildAlertCard(
                icon: Icons.info_outline,
                title: "No Insights Yet",
                message: "Tap 'Refresh' to get your personalized financial tips!",
                backgroundColor: Colors.blueGrey.withOpacity(0.05),
                iconColor: Colors.blueGrey,
                borderColor: Colors.blueGrey.withOpacity(0.2),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _insights.length,
                itemBuilder: (context, index) {
                  final insight = _insights[index];
                  return _buildAlertCard(
                    icon: insight.icon, // Uses icon from AiInsight
                    title: insight.title,
                    message: insight.message,
                    backgroundColor: insight.backgroundColor, // Uses color from AiInsight
                    iconColor: insight.iconColor,           // Uses color from AiInsight
                    borderColor: insight.borderColor,         // Uses color from AiInsight
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 12),
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: _isLoading ? null : _fetchInsights,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'Refresh Insights',
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

  Widget _buildErrorCard(String errorMessage) {
    return _buildAlertCard(
      icon: Icons.error_outline,
      title: "Error",
      message: errorMessage,
      backgroundColor: Colors.red.withOpacity(0.05),
      iconColor: Colors.red.shade700,
      borderColor: Colors.red.withOpacity(0.2),
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
      width: double.infinity,
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
            child: Icon(icon, color: iconColor, size: 20),
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
                    color: iconColor, // Use the dynamic iconColor for title
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF424242), // Keeping message text color consistent for readability
                    height: 1.4,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}