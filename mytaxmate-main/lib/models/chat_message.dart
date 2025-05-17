import 'package:flutter/material.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromUser(String text) {
    return ChatMessage(text: text, isUser: true);
  }

  factory ChatMessage.fromAssistant(String text) {
    return ChatMessage(text: text, isUser: false);
  }
}
