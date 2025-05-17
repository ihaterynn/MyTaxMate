import 'package:flutter/material.dart';
import 'dart:convert'; // For jsonEncode and jsonDecode
import 'package:http/http.dart' as http; // For making HTTP requests
import '../../main.dart'; // For AppGradients
import '../../services/expense_service.dart'; // Import your ExpenseService

class AiInsight {
  final String title; // Title can be generic like "Smart Tip" or derived
  final String message;
  final IconData icon;

  AiInsight({
    required this.title,
    required this.message,
    this.icon = Icons.lightbulb_outline,
  });
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

  final String _chatApiUrl = 'http://localhost:8000/chat'; // For Android Emulator
  // final String _chatApiUrl = 'http://YOUR_MACHINE_LOCAL_IP:8000/chat'; // For physical device/iOS Sim

  @override
  void initState() {
    super.initState();
    _fetchInsights();
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
        // The query now explicitly asks for a JSON list of concise points.
        // The backend system prompt for smart assistant queries will reinforce this.
        'query': 'Based on my recent expenses, provide a JSON list of 2-3 concise financial insights, spending patterns, and potential tax saving tips relevant to Malaysian context. Each item in the list should be a single, actionable sentence. Example: ["Your spending on X is high.", "Consider Y for tax relief."]',
        'expenses': expenses,
        'is_smart_assistant_query': true, // Indicate this is for the smart assistant
      };

      final response = await http.post(
        Uri.parse(_chatApiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 45)); // Increased timeout slightly

      if (response.statusCode == 200) {
        // The backend should now return a JSON body where 'assistant_reply' is a list of strings
        final responseData = jsonDecode(utf8.decode(response.bodyBytes)); 
        final dynamic assistantReply = responseData['assistant_reply'];

        if (assistantReply is List) {
          _insights = assistantReply.map<AiInsight>((item) {
            if (item is String) {
              // Simple title, or you can try to derive one if the AI provides more structure
              return AiInsight(title: "Smart Tip", message: item);
            } else {
              // Fallback for unexpected item type in the list
              return AiInsight(title: "Insight", message: "Received unexpected insight format.");
            }
          }).toList();
          if (_insights.isEmpty) {
             _insights.add(AiInsight(title: "Smart Insight", message: "No specific insights generated this time."));
          }
        } else if (assistantReply is String) {
          // Fallback if the backend didn't return a list (e.g., error or old format)
          _insights.add(AiInsight(title: "Smart Insight", message: assistantReply));
        } else {
          _errorMessage = 'Received unexpected response format from the assistant.';
        }
      } else {
        print('Failed to load insights: ${response.statusCode} ${response.body}');
        _errorMessage = 'Failed to load insights: ${response.statusCode}. Details: ${response.body.substring(0, (response.body.length > 100) ? 100 : response.body.length)}';
      }
    } catch (e) {
      print('Error fetching insights: $e');
      _errorMessage = 'An error occurred: ${e.toString()}. Check connection or server.';
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
                    Icons.lightbulb_outline,
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
                physics: const NeverScrollableScrollPhysics(), // To use inside Column
                itemCount: _insights.length,
                itemBuilder: (context, index) {
                  final insight = _insights[index];
                  return _buildAlertCard(
                    icon: insight.icon,
                    title: insight.title, // Could be "Smart Tip 1", "Smart Tip 2" etc.
                    message: insight.message,
                    backgroundColor: const Color(0xFFE3F2FD), // Light blue background
                    iconColor: const Color(0xFF1B5886), // Darker blue icon
                    borderColor: const Color(0xFFBBDEFB), // Lighter blue border
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
                    color: iconColor, // Use iconColor for title for consistency
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF424242), // Slightly darker text for better readability
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