import 'package:flutter/foundation.dart';

enum MessageRole { user, assistant, system, tool }

@immutable
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime? timestamp;
  final bool isStreaming;
  final Map<String, dynamic>? toolCall;
  final String? toolResult;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.timestamp,
    this.isStreaming = false,
    this.toolCall,
    this.toolResult,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] as String?) ?? 'user';
    final role = _parseRole(roleStr);
    final content = _extractContent(json['content']);
    final ts = json['timestamp'];
    return ChatMessage(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: role,
      content: content,
      timestamp: ts != null
          ? DateTime.fromMillisecondsSinceEpoch((ts as num).toInt())
          : null,
    );
  }

  static MessageRole _parseRole(String r) {
    switch (r) {
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      case 'tool':
        return MessageRole.tool;
      default:
        return MessageRole.user;
    }
  }

  static String _extractContent(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is List) {
      final parts = <String>[];
      for (final item in raw) {
        if (item is Map) {
          if (item['type'] == 'text') {
            parts.add((item['text'] as String?) ?? '');
          } else if (item['type'] == 'tool_use') {
            parts.add('[Tool: ${item['name']}]');
          } else if (item['type'] == 'tool_result') {
            final content = item['content'];
            if (content is String) parts.add(content);
          }
        } else if (item is String) {
          parts.add(item);
        }
      }
      return parts.join('\n');
    }
    return raw.toString();
  }

  ChatMessage copyWith({String? content, bool? isStreaming}) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      toolCall: toolCall,
      toolResult: toolResult,
    );
  }

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isSystem => role == MessageRole.system;
  bool get isTool => role == MessageRole.tool;
}
