import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/conversational_ai_service.dart';
import '../l10n/app_strings.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final ConversationalAIService _aiService = ConversationalAIService.instance;
  List<Map<String, dynamic>> _chatHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _aiService.getChatHistory();
      setState(() {
        _chatHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat history: $e')),
        );
      }
    }
  }

  Future<void> _loadChat(String chatId) async {
    try {
      final success = await _aiService.loadChat(chatId);
      if (success && mounted) {
        Navigator.pop(context, true); // Return true to indicate chat was loaded
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load chat')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat: $e')),
        );
      }
    }
  }

  Future<void> _deleteChat(String chatId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this chat? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _aiService.deleteChat(chatId);
        await _loadChatHistory(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting chat: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllChats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear All Chats',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete all chat history? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Clear All', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _aiService.clearAllChats();
        await _loadChatHistory(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All chats cleared successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing chats: $e')),
          );
        }
      }
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getStepDisplayName(String step) {
    switch (step) {
      case 'language_selection':
        return 'Language Selection';
      case 'greeting':
        return 'Getting Started';
      case 'category':
        return 'Selecting Category';
      case 'subcategory':
        return 'Selecting Type';
      case 'problem':
        return 'Describing Issue';
      case 'date':
        return 'Adding Date';
      case 'location':
        return 'Adding Location';
      case 'address':
        return 'Adding Address';
      case 'photo':
        return 'Adding Photo';
      case 'personal_details':
        return 'Contact Details';
      case 'summary':
        return 'Review';
      case 'confirm':
        return 'Confirming';
      case 'submitted':
        return 'Completed ✅';
      default:
        return 'In Progress';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Chat History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (_chatHistory.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear_all') {
                  _clearAllChats();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Clear All',
                        style: GoogleFonts.inter(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatHistory.isEmpty
              ? _buildEmptyState()
              : _buildChatList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _aiService.startNewChat();
          if (mounted) {
            Navigator.pop(context, true); // Return to chat with new session
          }
        },
        backgroundColor: const Color(0xFF1E66F5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'New Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1E66F5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: Color(0xFF1E66F5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Chat History',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation to report\nyour first complaint',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              await _aiService.startNewChat();
              if (mounted) {
                Navigator.pop(context, true);
              }
            },
            icon: const Icon(Icons.add),
            label: Text(
              'Start New Chat',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E66F5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return RefreshIndicator(
      onRefresh: _loadChatHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _chatHistory.length,
        itemBuilder: (context, index) {
          final chat = _chatHistory[index];
          return _buildChatItem(chat);
        },
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final isCompleted = chat['isCompleted'] == true;
    final categoryEmoji = chat['categoryEmoji'] ?? '📝';
    final title = chat['title'] ?? 'Untitled Chat';
    final lastMessage = chat['lastMessage'] ?? '';
    final timestamp = chat['timestamp'] ?? '';
    final step = chat['step'] ?? '';
    final chatId = chat['chatId'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isCompleted 
                ? const Color(0xFF10B981).withOpacity(0.1)
                : const Color(0xFF1E66F5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              categoryEmoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Completed',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (lastMessage.isNotEmpty)
              Text(
                lastMessage,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStepDisplayName(step),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _loadChat(chatId),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _deleteChat(chatId);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: GoogleFonts.inter(color: Colors.red, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
          child: const Icon(
            Icons.more_vert,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
        ),
      ),
    );
  }
}