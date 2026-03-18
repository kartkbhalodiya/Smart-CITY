import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ai_service.dart';

class AICallScreen extends StatefulWidget {
  const AICallScreen({super.key});

  @override
  State<AICallScreen> createState() => _AICallScreenState();
}

class _AICallScreenState extends State<AICallScreen>
    with TickerProviderStateMixin {
  final AIService _aiService = AIService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isAssistantActive = true;
  bool _showChat = false;
  bool _isProcessing = false;
  bool _isFetchingLocation = false;

  String _sessionDuration = '00:00';
  Timer? _sessionTimer;
  int _seconds = 0;

  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  AnimationController? _pulseController;

  AssistantReply? _latestReply;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _startAssistant();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _pulseController?.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _startAssistant() {
    setState(() => _isAssistantActive = true);
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _seconds++;
        final min = _seconds ~/ 60;
        final sec = _seconds % 60;
        _sessionDuration =
            '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
      });
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      const greeting =
          "Hello! I am JanHelp, your advanced complaint assistant. Use Chat to report issue, Camera to attach evidence, and Location to share your current spot.";
      _addMessage(greeting, false);
    });
  }

  Future<void> _handleUserInput(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty || _isProcessing) return;

    _addMessage(input, true);
    setState(() => _isProcessing = true);

    try {
      final reply = await _aiService.processUserInputAdvanced(input);
      _latestReply = reply;
      _addMessage(reply.response, false, metadata: reply.toMap());
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
        'time': DateTime.now(),
        'meta': metadata,
      });
    });
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
    _sessionTimer?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildCallInterface()),
                _buildControls(),
              ],
            ),
            if (_showChat) _buildChatOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            _sessionDuration,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isAssistantActive ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isAssistantActive ? 'Assistant Ready' : 'Idle',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallInterface() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController!,
            builder: (context, child) {
              return Container(
                width: 150 + (_pulseController!.value * 18),
                height: 150 + (_pulseController!.value * 18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF60A5FA).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: child,
              );
            },
            child: const CircleAvatar(
              radius: 75,
              backgroundColor: Color(0xFF1E66F5),
              child: Icon(Icons.smart_toy, size: 60, color: Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'JanHelp - AI Assistant',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Advanced civic intelligence for every citizen',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 18),
          _buildInsightPanel(),
        ],
      ),
    );
  }

  Widget _buildInsightPanel() {
    if (_latestReply == null) {
      return _statusCard(
        title: 'Live Analysis',
        child: const Text(
          'Start chatting to get smart issue analysis, urgency detection, and guided next steps.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      );
    }

    final reply = _latestReply!;
    return _statusCard(
      title: 'Live Analysis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Urgency: ${reply.urgency.toUpperCase()}',
                  reply.urgency == 'critical' ? Colors.red : Colors.blue),
              _chip('Mood: ${reply.mood}', Colors.teal),
              if (reply.category != null) _chip(reply.category!, Colors.orange),
              _chip('Confidence ${(reply.confidence * 100).round()}%',
                  Colors.purple),
            ],
          ),
          if (reply.missingFields.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Still needed: ${reply.missingFields.join(', ')}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if (reply.actionChecklist.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...reply.actionChecklist.take(2).map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '- $action',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chat',
                onTap: () => setState(() => _showChat = true),
                isActive: _showChat,
              ),
              _buildControlButton(
                icon: Icons.history_rounded,
                label: 'History',
                onTap: _openHistoryPanel,
              ),
              _buildControlButton(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: _handleCameraUpload,
              ),
              _buildControlButton(
                icon: _isFetchingLocation
                    ? Icons.location_searching_rounded
                    : Icons.my_location_rounded,
                label: 'Location',
                onTap: _shareCurrentLocation,
                isActive: _isFetchingLocation,
              ),
              _buildControlButton(
                icon: Icons.call_rounded,
                label: 'Call',
                onTap: _showCallComingSoon,
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _closeAssistant,
            child: Container(
              width: 120,
              height: 46,
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.all(Radius.circular(26)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1E66F5) : Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  void _showCallComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI voice calling feature is coming soon.'),
      ),
    );
  }

  Future<void> _handleCameraUpload() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: Colors.white70),
              title: const Text('Capture from camera',
                  style: TextStyle(color: Colors.white)),
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
              leading: const Icon(Icons.photo_library_rounded,
                  color: Colors.white70),
              title: const Text('Choose image from gallery',
                  style: TextStyle(color: Colors.white)),
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
              leading:
                  const Icon(Icons.attach_file_rounded, color: Colors.white70),
              title: const Text('Upload file',
                  style: TextStyle(color: Colors.white)),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'Conversation History',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: _chatMessages.isEmpty
                      ? const Center(
                          child: Text(
                            'No history yet',
                            style: TextStyle(color: Colors.white60),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _chatMessages.length,
                          itemBuilder: (context, index) {
                            final msg = _chatMessages[index];
                            final isUser = msg['isUser'] == true;
                            final text = msg['text'] as String? ?? '';
                            final time =
                                msg['time'] as DateTime? ?? DateTime.now();
                            return ListTile(
                              leading: Icon(
                                isUser
                                    ? Icons.person
                                    : Icons.smart_toy_outlined,
                                color: isUser
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF22C55E),
                              ),
                              title: Text(
                                text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                _formatMessageTime(time),
                                style: const TextStyle(color: Colors.white54),
                              ),
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

  Widget _buildChatOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1220), Color(0xFF111827), Color(0xFF070B12)],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => setState(() => _showChat = false),
                  ),
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF1E66F5),
                    child:
                        Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JanHelp Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Advanced civic assistant',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _openHistoryPanel,
                    icon: const Icon(Icons.history_rounded,
                        color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
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
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'JanHelp is analyzing your issue...',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] == true;
    final text = message['text'] as String? ?? '';
    final meta = message['meta'] as Map<String, dynamic>?;
    final time = message['time'] as DateTime? ?? DateTime.now();
    final accent = isUser ? const Color(0xFF1E66F5) : const Color(0xFF334155);
    final bubbleColor =
        isUser ? const Color(0xFF1D4ED8) : const Color(0xFF1F2937);
    final chips = _buildMetaChips(meta);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.95),
                  ),
                  child: const Icon(Icons.support_agent,
                      color: Colors.white, size: 17),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 16),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isUser ? 'You' : 'JanHelp AI',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatMessageTime(time),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style:
                            const TextStyle(color: Colors.white, height: 1.4),
                      ),
                      if (!isUser && chips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: chips),
                      ],
                      if (!isUser &&
                          meta != null &&
                          (meta['nextQuestion'] as String?) != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Next: ${meta['nextQuestion']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8, bottom: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.95),
                  ),
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
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
        color: Color(0xFF0B1220),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTypedMessage(),
              decoration: InputDecoration(
                hintText: 'Describe your issue...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.edit_note_rounded, color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF60A5FA)),
                ),
                filled: true,
                fillColor: const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF1F2937),
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white70, size: 18),
              onPressed: _handleCameraUpload,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF1F2937),
            ),
            child: IconButton(
              icon: const Icon(Icons.my_location_rounded,
                  color: Colors.white70, size: 18),
              onPressed: _shareCurrentLocation,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
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

  void _sendTypedMessage() {
    final input = _chatController.text.trim();
    if (input.isEmpty) return;
    _chatController.clear();
    _handleUserInput(input);
  }
}
