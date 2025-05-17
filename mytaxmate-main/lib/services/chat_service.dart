import 'dart:async';
import '../models/chat_message.dart';

class ChatService {
  // Singleton pattern
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // List of predefined responses for demo purposes
  final List<String> _predefinedResponses = [
    "Based on your recent expenses, you could potentially claim RM 1,200 in tax deductions for your workspace expenses.",
    "I noticed you've spent RM 350 on software this month. Did you know that business software expenses are tax-deductible?",
    "Your records show consistent meal expenses. For business meals, you can claim 50% of these expenses as tax deductions.",
    "Looking at your spending patterns, you might benefit from setting up a Lifestyle Tax Relief claim. Would you like more information about this?",
    "Your tax filing deadline is approaching in 45 days. Would you like me to help you prepare your documentation?",
    "Based on your income and expenses, you might qualify for the M40 tax incentives. I can provide more details if you're interested.",
  ];

  final List<ChatMessage> _chatHistory = [];
  final _chatStreamController = StreamController<List<ChatMessage>>.broadcast();

  Stream<List<ChatMessage>> get chatStream => _chatStreamController.stream;
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  void addUserMessage(String message) {
    final userMessage = ChatMessage.fromUser(message);
    _chatHistory.add(userMessage);
    _chatStreamController.add(_chatHistory);

    // Simulate a delay before the assistant responds
    Timer(const Duration(milliseconds: 800), () {
      _generateAssistantResponse(message);
    });
  }

  void _generateAssistantResponse(String userMessage) {
    // In a real app, this would call an actual backend service
    // For demo purposes, we'll just use a random predefined response
    final assistantMessage = ChatMessage.fromAssistant(
      _getResponse(userMessage),
    );

    _chatHistory.add(assistantMessage);
    _chatStreamController.add(_chatHistory);
  }

  String _getResponse(String userMessage) {
    // Simple keyword matching for demo purposes
    userMessage = userMessage.toLowerCase();

    if (userMessage.contains('deduction') || userMessage.contains('deduct')) {
      return "Tax deductions reduce your taxable income. Common deductions include approved donations, medical expenses for parents, lifestyle expenses, and personal education fees.";
    } else if (userMessage.contains('relief') ||
        userMessage.contains('exemption')) {
      return "In Malaysia, you can claim tax relief for medical expenses, education fees, lifestyle purchases, and retirement contributions, among others.";
    } else if (userMessage.contains('deadline') ||
        userMessage.contains('due date')) {
      return "For the 2023 tax year, e-Filing deadline is typically April 30, 2024, for individuals without business income, and June 30, 2024, for those with business income.";
    } else if (userMessage.contains('hello') ||
        userMessage.contains('hi') ||
        userMessage.contains('hey')) {
      return "Hello! I'm your MyTaxMate assistant. How can I help you with your tax or financial questions today?";
    } else {
      // Return a random predefined response
      return _predefinedResponses[DateTime.now().microsecond %
          _predefinedResponses.length];
    }
  }

  void clearChat() {
    _chatHistory.clear();
    _chatStreamController.add(_chatHistory);
  }

  void dispose() {
    _chatStreamController.close();
  }
}
