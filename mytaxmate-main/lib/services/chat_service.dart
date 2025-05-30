import 'dart:async';
import 'dart:convert'; 
import 'package:http/http.dart' as http; 
import '../models/chat_message.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  static const String _backendUrl = 'http://localhost:8003/chat';

  final List<ChatMessage> _chatHistory = [];
  final _chatStreamController = StreamController<List<ChatMessage>>.broadcast();

  Stream<List<ChatMessage>> get chatStream => _chatStreamController.stream;
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  void addUserMessage(String message) {
    final userMessage = ChatMessage.fromUser(message);
    _chatHistory.add(userMessage);
    _chatStreamController.add(List.from(_chatHistory)); 

    // Call the backend to generate assistant response
    _generateAssistantResponse(message);
  }

  Future<void> _generateAssistantResponse(String userMessage) async {
    // Prepare the history in the format expected by the backend
    // The backend expects a list of {'role': 'user'/'assistant', 'content': '...'}
    // Our ChatMessage model has 'text' and 'isUser'
    List<Map<String, String>> historyPayload = _chatHistory
        .where((msg) => msg.text != userMessage) // Exclude the current message if it's already added
        .map((msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.text,
            })
        .toList();

    try {
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'message': userMessage, // Changed 'query' to 'message'
          'history': historyPayload, // Added history
          'expenses': [], // Added expenses (empty for now)
          'is_smart_assistant_query': false, // Added flag (false for now)
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes)); // handle UTF-8
        final assistantReply = responseData['assistant_reply'] as String?;
        if (assistantReply != null) {
          final assistantMessage = ChatMessage.fromAssistant(assistantReply);
          _chatHistory.add(assistantMessage);
        } else {
          _addErrorMessage("Received an empty response from the assistant.");
        }
      } else {
        print('Failed to get response from backend: ${response.statusCode}');
        print('Response body: ${response.body}');
        _addErrorMessage("Error: Could not reach the tax assistant (Status: ${response.statusCode}).");
      }
    } catch (e) {
      print('Error connecting to backend: $e');
      _addErrorMessage("Error: Could not connect to the tax assistant.");
    }
    _chatStreamController.add(List.from(_chatHistory)); 
  }

  void _addErrorMessage(String errorMessageText) {
    final errorMessage = ChatMessage.fromAssistant(errorMessageText);
    _chatHistory.add(errorMessage);
  }

  void clearChat() {
    _chatHistory.clear();
    _chatStreamController.add(List.from(_chatHistory));
  }

  void dispose() {
    _chatStreamController.close();
  }
}
