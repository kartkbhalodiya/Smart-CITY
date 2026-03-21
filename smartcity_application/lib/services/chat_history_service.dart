import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final List<Map<String, dynamic>> messages;
  final String? complaintId;
  final bool isCompleted;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messages,
    this.complaintId,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastMessageAt': lastMessageAt.toIso8601String(),
        'messages': messages,
        'complaintId': complaintId,
        'isCompleted': isCompleted,
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'],
        title: json['title'],
        createdAt: DateTime.parse(json['createdAt']),
        lastMessageAt: DateTime.parse(json['lastMessageAt']),
        messages: List<Map<String, dynamic>>.from(json['messages'] ?? []),
        complaintId: json['complaintId'],
        isCompleted: json['isCompleted'] ?? false,
      );

  String get displayTime {
    final now = DateTime.now();
    final difference = now.difference(lastMessageAt);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo ago';
    return '${(difference.inDays / 365).floor()}y ago';
  }
}

class ChatHistoryService {
  static const String _keyPrefix = 'chat_history_';
  static const String _sessionListKey = 'chat_sessions_list';
  static const String _currentSessionKey = 'current_chat_session';

  // Save current chat session
  Future<void> saveCurrentSession(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, json.encode(session.toJson()));
    await _addToSessionList(session.id);
  }

  // Load current chat session
  Future<ChatSession?> loadCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionData = prefs.getString(_currentSessionKey);
    if (sessionData == null) return null;
    return ChatSession.fromJson(json.decode(sessionData));
  }

  // Save a chat session to history
  Future<void> saveSession(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix${session.id}',
      json.encode(session.toJson()),
    );
    await _addToSessionList(session.id);
  }

  // Load a specific session
  Future<ChatSession?> loadSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionData = prefs.getString('$_keyPrefix$sessionId');
    if (sessionData == null) return null;
    return ChatSession.fromJson(json.decode(sessionData));
  }

  // Get all chat sessions
  Future<List<ChatSession>> getAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionIds = prefs.getStringList(_sessionListKey) ?? [];
    
    final sessions = <ChatSession>[];
    for (final id in sessionIds) {
      final session = await loadSession(id);
      if (session != null) {
        sessions.add(session);
      }
    }
    
    // Sort by last message time (newest first)
    sessions.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return sessions;
  }

  // Delete a session
  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$sessionId');
    await _removeFromSessionList(sessionId);
  }

  // Clear current session
  Future<void> clearCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
  }

  // Start new chat (save current to history if exists)
  Future<String> startNewChat() async {
    // Save current session to history if it exists
    final currentSession = await loadCurrentSession();
    if (currentSession != null && currentSession.messages.isNotEmpty) {
      await saveSession(currentSession);
    }
    
    // Clear current session
    await clearCurrentSession();
    
    // Generate new session ID
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Private helper methods
  Future<void> _addToSessionList(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionIds = prefs.getStringList(_sessionListKey) ?? [];
    if (!sessionIds.contains(sessionId)) {
      sessionIds.add(sessionId);
      await prefs.setStringList(_sessionListKey, sessionIds);
    }
  }

  Future<void> _removeFromSessionList(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionIds = prefs.getStringList(_sessionListKey) ?? [];
    sessionIds.remove(sessionId);
    await prefs.setStringList(_sessionListKey, sessionIds);
  }

  // Generate chat title from first user message
  String generateChatTitle(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return 'New Chat';
    
    // Find first user message
    final firstUserMessage = messages.firstWhere(
      (msg) => msg['isUser'] == true,
      orElse: () => {'text': 'New Chat'},
    );
    
    String text = firstUserMessage['text'] ?? 'New Chat';
    
    // Truncate if too long
    if (text.length > 50) {
      text = '${text.substring(0, 47)}...';
    }
    
    return text;
  }
}
