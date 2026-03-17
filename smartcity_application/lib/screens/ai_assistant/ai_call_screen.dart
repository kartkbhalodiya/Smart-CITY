import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/ai_service.dart';
import '../../services/speech_service.dart';

class AICallScreen extends StatefulWidget {
  @override
  _AICallScreenState createState() => _AICallScreenState();
}

class _AICallScreenState extends State<AICallScreen> with TickerProviderStateMixin {
  final AIService _aiService = AIService();
  final SpeechService _speechService = SpeechService();
  
  bool _isCallActive = false;
  bool _isSpeakerOn = false;
  bool _isMuted = false;
  bool _isBluetoothConnected = false;
  bool _showChat = false;
  String _callDuration = "00:00";
  Timer? _callTimer;
  int _seconds = 0;
  
  List<Map<String, dynamic>> _chatMessages = [];
  TextEditingController _chatController = TextEditingController();
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: Duration(seconds: 2))..repeat();
    _startCall();
  }

  void _startCall() {
    setState(() => _isCallActive = true);
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        int min = _seconds ~/ 60;
        int sec = _seconds % 60;
        _callDuration = "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
      });
    });
    _speechService.startListening(_onSpeechResult);
  }

  void _onSpeechResult(String text) {
    if (text.isNotEmpty) {
      _addMessage(text, true);
      
      // Detect language and respond accordingly
      String detectedLang = _detectLanguage(text);
      
      _aiService.processUserInput(text).then((response) {
        _addMessage(response, false);
        
        // Speak in detected language
        if (detectedLang == 'hi') {
          _speechService.speakHindi(response);
        } else if (detectedLang == 'gu') {
          _speechService.speakGujarati(response);
        } else {
          _speechService.speak(response);
        }
      });
    }
  }

  String _detectLanguage(String text) {
    // Simple language detection based on script
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi'; // Devanagari
    if (RegExp(r'[\u0A80-\u0AFF]').hasMatch(text)) return 'gu'; // Gujarati
    return 'en';
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _chatMessages.add({"text": text, "isUser": isUser, "time": DateTime.now()});
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    _speechService.stop();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _pulseController?.dispose();
    _chatController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1a1a2e),
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
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_callDuration, style: TextStyle(color: Colors.white70, fontSize: 16)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text("Active", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCallInterface() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController!,
          builder: (context, child) {
            return Container(
              width: 150 + (_pulseController!.value * 20),
              height: 150 + (_pulseController!.value * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.blue.withOpacity(0.3), Colors.transparent],
                ),
              ),
              child: child,
            );
          },
          child: CircleAvatar(
            radius: 75,
            backgroundColor: Colors.blue,
            child: Icon(Icons.smart_toy, size: 60, color: Colors.white),
          ),
        ),
        SizedBox(height: 24),
        Text("AI Assistant", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text("Smart City Helper", style: TextStyle(color: Colors.white70, fontSize: 16)),
        SizedBox(height: 24),
        if (_speechService.isListening)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text("Listening...", style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                label: "Speaker",
                onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                isActive: _isSpeakerOn,
              ),
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: "Mute",
                onTap: () => setState(() => _isMuted = !_isMuted),
                isActive: _isMuted,
              ),
              _buildControlButton(
                icon: Icons.bluetooth,
                label: "Bluetooth",
                onTap: () => setState(() => _isBluetoothConnected = !_isBluetoothConnected),
                isActive: _isBluetoothConnected,
              ),
              _buildControlButton(
                icon: Icons.chat,
                label: "Chat",
                onTap: () => setState(() => _showChat = !_showChat),
                isActive: _showChat,
              ),
            ],
          ),
          SizedBox(height: 24),
          GestureDetector(
            onTap: _endCall,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.call_end, color: Colors.white, size: 35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive ? Colors.blue : Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              title: Text("Chat with AI"),
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => setState(() => _showChat = false),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  return _buildChatBubble(msg['text'], msg['isUser']);
                },
              ),
            ),
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
                fillColor: Colors.grey[800],
              ),
            ),
          ),
          SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: () {
                if (_chatController.text.isNotEmpty) {
                  _addMessage(_chatController.text, true);
                  _aiService.processUserInput(_chatController.text).then((response) {
                    _addMessage(response, false);
                  });
                  _chatController.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
