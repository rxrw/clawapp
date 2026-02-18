import 'package:flutter/foundation.dart';

@immutable
class Session {
  final String key;
  final String? sessionId;
  final String? label;
  final String? displayName;
  final String? derivedTitle;
  final String? lastMessagePreview;
  final String? model;
  final String? modelProvider;
  final String? subject;
  final String? chatType;
  final String? provider;
  final String? groupChannel;
  final int? updatedAt;
  final int? contextTokens;
  final int? totalTokens;

  const Session({
    required this.key,
    this.sessionId,
    this.label,
    this.displayName,
    this.derivedTitle,
    this.lastMessagePreview,
    this.model,
    this.modelProvider,
    this.subject,
    this.chatType,
    this.provider,
    this.groupChannel,
    this.updatedAt,
    this.contextTokens,
    this.totalTokens,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      key: json['key'] as String,
      sessionId: json['sessionId'] as String?,
      label: json['label'] as String?,
      displayName: json['displayName'] as String?,
      derivedTitle: json['derivedTitle'] as String?,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      model: json['model'] as String?,
      modelProvider: json['modelProvider'] as String?,
      subject: json['subject'] as String?,
      chatType: json['chatType'] as String?,
      provider: json['provider'] as String?,
      groupChannel: json['groupChannel'] as String?,
      updatedAt: json['updatedAt'] as int?,
      contextTokens: json['contextTokens'] as int?,
      totalTokens: json['totalTokens'] as int?,
    );
  }

  /// Human-readable title for this session
  String get title {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (label != null && label!.isNotEmpty) return label!;
    if (derivedTitle != null && derivedTitle!.isNotEmpty) return derivedTitle!;
    if (subject != null && subject!.isNotEmpty) return subject!;
    // Parse session key for readable name
    final parts = key.split(':');
    if (parts.length >= 3) {
      final ch = parts.length > 2 ? parts[2] : '';
      return ch.isNotEmpty ? ch : key;
    }
    return key;
  }

  /// Session kind icon
  String get kindEmoji {
    if (key.contains(':group:')) return '👥';
    if (key.contains(':channel:')) return '#';
    if (key.contains(':direct:') || key.contains(':dm:')) return '💬';
    if (key == 'main' || key.endsWith(':main')) return '🏠';
    return '💬';
  }

  String? get channelName {
    if (provider != null) return provider;
    final parts = key.split(':');
    if (parts.length > 2) return parts[2];
    return null;
  }

  DateTime? get updatedAtDateTime {
    if (updatedAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(updatedAt!);
  }

  bool get isMain => key == 'main' || key.endsWith(':main');
}
