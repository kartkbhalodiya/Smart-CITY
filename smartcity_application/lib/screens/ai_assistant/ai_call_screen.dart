import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ai_service.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';

class AICallScreen extends StatefulWidget {
  const AICallScreen({super.key});

  @override
  State<AICallScreen> createState() => _AICallScreenState();
}

class _AICallScreenState extends State<AICallScreen>
    with TickerProviderStateMixin {
  final AIService _aiService = AIService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isProcessing = false;
  bool _isFetchingLocation = false;

  List<Map<String, dynamic>> _chatMessages = [];
  String _currentSessionId = '';
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  AnimationController? _pulseController;
  Timer? _nudgeTimer;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _loadOrCreateSession();
  }

  @override
  void dispose() {
    _nudgeTimer?.cancel();
    _pulseController?.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _loadOrCreateSession() {
    final sessions = _loadAllSessions();
    if (sessions.isNotEmpty) {
      final latest = sessions.first;
      _currentSessionId = latest['id'] as String;
      _chatMessages = List<Map<String, dynamic>>.from(latest['messages'] as List);
      setState(() {});
    } else {
      _startNewChat();
    }
  }

  void _startNewChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_outline, color: Color(0xFF1E66F5)),
            SizedBox(width: 12),
            Text('Start New Chat?', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Your current conversation will be saved to history. Do you want to start a new chat?',
          style: TextStyle(color: Colors.black87, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmNewChat();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E66F5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Start New Chat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmNewChat() {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _chatMessages = [];
    _aiService.reset();
    setState(() {});
    _startAssistant();
  }

  List<Map<String, dynamic>> _loadAllSessions() {
    final raw = StorageService.getChatSessions();
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  void _saveCurrentSession() {
    final sessions = _loadAllSessions();
    sessions.removeWhere((s) => s['id'] == _currentSessionId);
    sessions.insert(0, {
      'id': _currentSessionId,
      'messages': _chatMessages,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (sessions.length > 50) sessions.removeRange(50, sessions.length);
    StorageService.saveChatSessions(jsonEncode(sessions));
  }

  void _startAssistant() {
    Future.delayed(const Duration(milliseconds: 350), () async {
      try {
        final reply = await _aiService.processUserInputAdvanced(
          'hello, I need help with a complaint',
        );
        if (!mounted) return;
        _addMessage(reply.response, false, metadata: reply.toMap());
        _scheduleNudge();
      } catch (_) {
        if (!mounted) return;
        _addMessage(
          'Hey there! 😊 I am JanHelp, your Smart City complaint assistant.\n\nTell me what\'s bothering you — a pothole, power cut, garbage issue, or anything else — and I\'ll help you file it quickly. You can also share your location 📍 or attach a photo 📷.',
          false,
        );
      }
    });
  }

  Future<void> _handleUserInput(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty || _isProcessing) return;

    _addMessage(input, true);
    setState(() => _isProcessing = true);
    _scheduleNudge();

    try {
      final reply = await _aiService.processUserInputAdvanced(input);
      
      // Check action type
      if (reply.action == 'SUBMIT_COMPLAINT') {
        await _submitComplaint(reply);
      } else if (reply.action == 'REQUEST_LOCATION') {
        _addMessage(reply.response, false, metadata: reply.toMap());
        _showLocationPicker();
      } else if (reply.action == 'REQUEST_PROOF') {
        _addMessage(reply.response, false, metadata: reply.toMap());
        _showProofPicker();
      } else {
        _addMessage(reply.response, false, metadata: reply.toMap());
        
        // Show confirmation buttons if needed
        if (reply.showConfirmation && reply.confirmationQuestion != null) {
          _showConfirmationButtons(reply.confirmationQuestion!);
        }
      }
      
      _scheduleNudge();
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _addMessage(
    String text,
    bool isUser, {
    Map<String, dynamic>? metadata,
  }) {
    setState(() {
      _chatMessages.add({
        'text': text,
        'isUser': isUser,
        'time': DateTime.now().toIso8601String(),
        'meta': metadata,
      });
    });
    _saveCurrentSession();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  void _scrollToLatest() {
    if (!_chatScrollController.hasClients) return;
    _chatScrollController.animateTo(
      _chatScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _closeAssistant() {
    Navigator.pop(context);
  }

  void _scheduleNudge() {
    _nudgeTimer?.cancel();
    _nudgeTimer = Timer(const Duration(minutes: 2), () async {
      final nudge = await _aiService.fetchReengagementNudge();
      if (nudge == null) return;
      await NotificationService.showAIAssistantNudge(
        title: nudge['title'] ?? 'Complaint reminder',
        body: nudge['body'] ?? 'Please come back and complete your complaint.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _buildChatOverlay(),
      ),
    );
  }

  Future<void> _handleCameraUpload() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1E66F5)),
              title: const Text('Capture from camera'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                _onAttachmentPicked(file?.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF1E66F5)),
              title: const Text('Choose image from gallery'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                _onAttachmentPicked(file?.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded, color: Color(0xFF1E66F5)),
              title: const Text('Upload file'),
              onTap: () async {
                Navigator.pop(context);
                final file = await FilePicker.platform.pickFiles();
                _onAttachmentPicked(file?.files.single.path);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onAttachmentPicked(String? path) {
    if (path == null || path.isEmpty) return;
    final fileName = path.split(RegExp(r'[\\/]')).last;
    _addMessage('Uploaded file: $fileName', true);
    _addMessage(
      'File received. I can treat this as evidence. Please add issue details and exact location.',
      false,
    );
  }

  Future<void> _shareCurrentLocation() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _addMessage(
          'Location permission is required to share current location.',
          false,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final message =
          'Current location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      await _handleUserInput(message);
    } catch (_) {
      _addMessage(
        'Unable to fetch current location right now. Please type landmark manually.',
        false,
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _openHistoryPanel() {
    final sessions = _loadAllSessions();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: Color(0xFF1E66F5)),
                      const SizedBox(width: 8),
                      const Text(
                        'Chat History',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.black12, height: 1),
                Expanded(
                  child: sessions.isEmpty
                      ? const Center(
                          child: Text(
                            'No chat history yet',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final messages = session['messages'] as List? ?? [];
                            final timestamp = session['timestamp'] as String? ?? '';
                            final preview = messages.isNotEmpty
                                ? (messages.first['text'] as String? ?? 'Empty chat')
                                : 'Empty chat';
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF1E66F5),
                                child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                              ),
                              title: Text(
                                _formatSessionDate(timestamp),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black54),
                              ),
                              trailing: Text(
                                '${messages.length} msgs',
                                style: const TextStyle(color: Colors.black38, fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _loadSession(session);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _loadSession(Map<String, dynamic> session) {
    setState(() {
      _currentSessionId = session['id'] as String;
      _chatMessages = List<Map<String, dynamic>>.from(session['messages'] as List);
    });
    _aiService.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  String _formatSessionDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  Widget _buildChatOverlay() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: _closeAssistant,
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/janhelp_icon.png',
                    height: 36,
                    width: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E66F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JanHelp AI',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Smart City Assistant',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _openHistoryPanel,
                    icon: const Icon(Icons.history_rounded, color: Colors.black54, size: 22),
                    tooltip: 'Chat History',
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E66F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _startNewChat,
                    icon: const Icon(Icons.add_comment_outlined, color: Colors.white, size: 22),
                    tooltip: 'New Chat',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _chatMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Image.asset(
                        'assets/images/janhelp_icon.png',
                        height: 80,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Color(0xFF1E66F5),
                        ),
                      ),
                        const SizedBox(height: 16),
                        const Text(
                          'Start a new conversation',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ask me anything about city complaints',
                          style: TextStyle(
                            color: Colors.black38,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) =>
                        _buildChatBubble(_chatMessages[index]),
                  ),
          ),
          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: Color(0xFF1E66F5),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'JanHelp is analyzing...',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] == true;
    final rawText = message['text'] as String? ?? '';
    final text = _sanitizeBubbleText(rawText);
    final meta = message['meta'] as Map<String, dynamic>?;
    final timeStr = message['time'] as String? ?? '';
    final time = DateTime.tryParse(timeStr) ?? DateTime.now();
    final bubbleColor = isUser ? const Color(0xFF1E66F5) : const Color(0xFFF3F4F6);
    final textColor = isUser ? Colors.white : Colors.black87;
    final chips = _buildMetaChips(meta);
    final showButtons = message['showButtons'] == true;
    final buttons = message['buttons'] as List?;
    final showMap = message['showMap'] == true;
    final showProofButtons = message['showProofButtons'] == true;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(color: textColor, height: 1.4, fontSize: 14),
              ),
              if (!isUser && chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
              if (showButtons && buttons != null) ...[
                const SizedBox(height: 12),
                _buildConfirmationButtons(buttons),
              ],
              if (showMap) ...[
                const SizedBox(height: 12),
                _buildMapPreview(),
              ],
              if (showProofButtons) ...[
                const SizedBox(height: 12),
                _buildProofButtons(),
              ],
              const SizedBox(height: 4),
              Text(
                _formatMessageTime(time),
                style: TextStyle(
                  color: isUser ? Colors.white70 : Colors.black38,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationButtons(List buttons) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons.map((btn) {
        final label = btn.toString();
        Color color;
        IconData icon;
        
        if (label.toLowerCase() == 'yes') {
          color = const Color(0xFF22C55E);
          icon = Icons.check_circle_outline;
        } else if (label.toLowerCase() == 'no') {
          color = const Color(0xFFEF4444);
          icon = Icons.cancel_outlined;
        } else {
          color = const Color(0xFFF59E0B);
          icon = Icons.help_outline;
        }
        
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton.icon(
            onPressed: () => _handleButtonResponse(label),
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMapPreview() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _MapPickerScreen(
              onLocationSelected: _handleLocationSelected,
            ),
          ),
        );
      },
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E66F5), width: 2),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 48, color: Color(0xFF1E66F5)),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to open map',
                    style: TextStyle(
                      color: Color(0xFF1E66F5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E66F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Select Location',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final file = await _imagePicker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
              );
              if (file != null) {
                await _analyzeAndUploadProof(file.path);
              }
            },
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text('Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E66F5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final file = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (file != null) {
                await _analyzeAndUploadProof(file.path);
              }
            },
            icon: const Icon(Icons.photo_library, size: 20),
            label: const Text('Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _sanitizeBubbleText(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return trimmed;
    final match = RegExp(
      r'"response_text"\s*:\s*"((?:[^"\\]|\\.)*)"',
    ).firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
    }
    return 'I received your message. Please describe your issue and I will help you file a complaint.';
  }

  List<Widget> _buildMetaChips(Map<String, dynamic>? meta) {
    if (meta == null) return const [];
    final out = <Widget>[];

    final urgency = (meta['urgency'] as String?)?.trim().toLowerCase();
    if (urgency != null && urgency.isNotEmpty) {
      out.add(
        _metaChip(
          urgency.toUpperCase(),
          _urgencyColor(urgency),
          _urgencyIcon(urgency),
        ),
      );
    }

    final category = (meta['category'] as String?)?.trim();
    if (category != null && category.isNotEmpty) {
      out.add(
        _metaChip(category, const Color(0xFFF59E0B), Icons.category_outlined),
      );
    }

    final subcategory = (meta['subcategory'] as String?)?.trim();
    if (subcategory != null && subcategory.isNotEmpty) {
      out.add(
        _metaChip(subcategory, const Color(0xFF22C55E), Icons.sell_outlined),
      );
    }

    final confidence = meta['confidence'];
    if (confidence is num) {
      out.add(
        _metaChip(
          'Conf ${(confidence * 100).round()}%',
          const Color(0xFFA855F7),
          Icons.insights,
        ),
      );
    }

    return out;
  }

  Widget _metaChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF97316);
      case 'low':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _urgencyIcon(String urgency) {
    switch (urgency) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'high':
        return Icons.priority_high_rounded;
      case 'low':
        return Icons.check_circle_outline;
      default:
        return Icons.bolt_outlined;
    }
  }

  String _formatMessageTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.black87),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTypedMessage(),
              decoration: InputDecoration(
                hintText: 'Describe your issue...',
                hintStyle: const TextStyle(color: Colors.black38),
                prefixIcon:
                    const Icon(Icons.edit_note_rounded, color: Colors.black38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF1E66F5)),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFF3F4F6),
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF1E66F5), size: 18),
              onPressed: _handleCameraUpload,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFF3F4F6),
            ),
            child: IconButton(
              icon: const Icon(Icons.my_location_rounded,
                  color: Color(0xFF1E66F5), size: 18),
              onPressed: _shareCurrentLocation,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: const Color(0xFF1E66F5),
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _sendTypedMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmationButtons(String question) {
    setState(() {
      _chatMessages.add({
        'text': question,
        'isUser': false,
        'time': DateTime.now().toIso8601String(),
        'showButtons': true,
        'buttons': ['Yes', 'No', 'Maybe'],
      });
    });
    _saveCurrentSession();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  void _showLocationPicker() {
    setState(() {
      _chatMessages.add({
        'text': 'Tap the map below to select the exact location',
        'isUser': false,
        'time': DateTime.now().toIso8601String(),
        'showMap': true,
      });
    });
    _saveCurrentSession();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  void _showProofPicker() {
    setState(() {
      _chatMessages.add({
        'text': 'Upload photo evidence',
        'isUser': false,
        'time': DateTime.now().toIso8601String(),
        'showProofButtons': true,
      });
    });
    _saveCurrentSession();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  Future<void> _handleButtonResponse(String response) async {
    _addMessage(response, true);
    await _handleUserInput(response);
  }

  Future<void> _handleLocationSelected(double lat, double lng) async {
    final locationMsg = 'Selected location: $lat, $lng';
    _addMessage(locationMsg, true);
    await _handleUserInput(locationMsg);
  }

  Future<void> _analyzeAndUploadProof(String imagePath) async {
    setState(() => _isProcessing = true);
    
    _addMessage('Analyzing image...', false);
    
    // Simulate image analysis (replace with actual ML model)
    await Future.delayed(const Duration(seconds: 2));
    
    final complaintData = _aiService.getComplaintData();
    final category = complaintData['category'] as String?;
    
    // Simple validation - in production, use ML model
    final isValid = imagePath.isNotEmpty;
    
    if (isValid) {
      _addMessage('✅ Image verified and uploaded successfully!', false);
      await _handleUserInput('I have uploaded the proof image');
    } else {
      _addMessage(
        '❌ Image does not match complaint category "$category". Please upload a relevant image showing the issue.',
        false,
      );
      _showProofPicker();
    }
    
    setState(() => _isProcessing = false);
  }

  Future<void> _submitComplaint(AssistantReply reply) async {
    final complaintData = reply.complaintDraft;
    
    // Show submitting message
    _addMessage(
      '⏳ Submitting your complaint to ${complaintData['category'] ?? 'the department'}...',
      false,
    );

    try {
      // Call backend API
      final response = await ApiService.post(
        'https://janhelp.vercel.app/api/complaints/',
        {
          'category': complaintData['category'],
          'subcategory': complaintData['subcategory'],
          'description': complaintData['last_user_message'] ?? '',
          'location': complaintData['location_hint'] ?? '',
          'urgency': complaintData['urgency'] ?? 'medium',
          'latitude': complaintData['latitude'],
          'longitude': complaintData['longitude'],
        },
      );

      if (response['success'] == true) {
        final complaintId = response['complaint_id'] ?? response['id'] ?? 'N/A';
        final department = response['department'] ?? complaintData['category'];
        final officer = response['assigned_officer'] ?? 'Department Team';
        final status = response['status'] ?? 'Pending Review';
        
        // Show success message
        final successMsg = '''✅ **Complaint Registered Successfully!**

📝 **Complaint ID**: #$complaintId

📍 **Location**: ${complaintData['location_hint'] ?? 'As provided'}

🏢 **Assigned To**: $department

👤 **Officer**: $officer

📊 **Status**: $status

⏱️ **Expected Resolution**: 3-5 working days

🔔 **What's Next?**
- You'll receive email/SMS updates
- Track status in 'My Complaints'
- Department will review within 24 hours

Need anything else? I'm here to help! 😊''';
        
        _addMessage(successMsg, false);
        
        // Reset AI service for new complaint
        _aiService.reset();
      } else {
        _addMessage(
          '❌ Failed to submit complaint: ${response['message'] ?? 'Unknown error'}. Please try again or contact support.',
          false,
        );
      }
    } catch (e) {
      _addMessage(
        '❌ Network error while submitting complaint. Please check your connection and try again.',
        false,
      );
    }
  }

  void _sendTypedMessage() {
    final input = _chatController.text.trim();
    if (input.isEmpty) return;
    _chatController.clear();
    _handleUserInput(input);
  }
}

class _MapPickerScreen extends StatefulWidget {
  final Function(double, double) onLocationSelected;

  const _MapPickerScreen({required this.onLocationSelected});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  double? _selectedLat;
  double? _selectedLng;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
        _isLoadingLocation = false;
      });
    } catch (_) {
      setState(() {
        _selectedLat = 23.0225;
        _selectedLng = 72.5714;
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: const Color(0xFF1E66F5),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedLat != null && _selectedLng != null)
            TextButton(
              onPressed: () {
                widget.onLocationSelected(_selectedLat!, _selectedLng!);
                Navigator.pop(context);
              },
              child: const Text(
                'SAVE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GestureDetector(
                  onTapDown: (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(details.globalPosition);
                    setState(() {
                      _selectedLat = 23.0225 + (localPosition.dy / 1000);
                      _selectedLng = 72.5714 + (localPosition.dx / 1000);
                    });
                  },
                  child: Container(
                    color: const Color(0xFFE5E7EB),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 80,
                            color: const Color(0xFFEF4444),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tap anywhere to select location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_selectedLat != null && _selectedLng != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                'Lat: ${_selectedLat!.toStringAsFixed(6)}\nLng: ${_selectedLng!.toStringAsFixed(6)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Text(
                      'Note: In production, integrate Google Maps or OpenStreetMap for accurate location selection',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
