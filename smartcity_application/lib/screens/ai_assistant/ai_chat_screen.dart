import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../../services/conversational_ai_service.dart';
import '../../services/chat_history_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/locale_provider.dart';
import '../../config/routes.dart';
import 'chat_history_screen.dart';
import '../../widgets/subcategory_selection_dialog.dart';
import 'ai_call_screen.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ConversationalAIService _aiService = ConversationalAIService();
  final ChatHistoryService _historyService = ChatHistoryService();
  final ImagePicker _imagePicker = ImagePicker();

  final List<ChatMessage> _messages = [];
  int? _selectedMessageIndex;
  bool _isLoading = false;
  bool _showInput = true;
  File? _selectedImage;
  File? _selectedProofFile;
  String? _selectedLocation;
  LatLng? _selectedLatLng;
  String? _currentSessionId;
  String? _complaintId;

  String _mapAiPriorityForBackend(dynamic rawPriority) {
    final normalized =
        (rawPriority ?? 'normal').toString().trim().toLowerCase();
    switch (normalized) {
      case 'critical':
      case 'urgent':
        return 'high';
      case 'high':
        return 'high';
      case 'medium':
        return 'medium';
      case 'low':
      case 'normal':
      default:
        return 'normal';
    }
  }

  void _addIfNotEmpty(Map<String, String> target, String key, dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) {
      target[key] = text;
    }
  }

  double _readComplaintCoordinate(
      Map<String, dynamic> complaintData, String key) {
    final raw = complaintData[key];
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse((raw ?? '').toString().trim()) ?? 0.0;
  }

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  String _pickFirstNonEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  Map<String, String> _extractSubmittedComplaintDetails(
    Map<String, dynamic> complaintData,
    Map<String, dynamic>? complaintResponse,
  ) {
    final departmentData =
        _asStringDynamicMap(complaintResponse?['assigned_department']);

    return {
      'category': _pickFirstNonEmpty([
        complaintResponse?['complaint_type_display'],
        complaintData['category'],
        complaintResponse?['complaint_type'],
        complaintData['category_key'],
      ], fallback: 'Unknown'),
      'subcategory': _pickFirstNonEmpty([
        complaintResponse?['subcategory'],
        complaintData['subcategory_display'],
        complaintData['subcategory'],
      ], fallback: 'Unknown'),
      'department': _pickFirstNonEmpty([
        departmentData?['name'],
        complaintData['assigned_department'],
        complaintData['department'],
      ], fallback: 'Assignment in progress'),
      'departmentPhone': _pickFirstNonEmpty([
        departmentData?['phone'],
        complaintData['department_phone'],
      ]),
      'departmentEmail': _pickFirstNonEmpty([
        departmentData?['email'],
        complaintData['department_email'],
      ]),
      'priority': _pickFirstNonEmpty([
        complaintResponse?['priority_display'],
        complaintData['priority'],
      ], fallback: 'Normal'),
      'slaHours': _pickFirstNonEmpty([
        departmentData?['sla_hours'],
      ], fallback: '48'),
    };
  }

  String _buildComplaintSubmittedMessage(
    Map<String, dynamic> complaintData,
    Map<String, dynamic>? complaintResponse,
    String complaintId,
  ) {
    final submitted =
        _extractSubmittedComplaintDetails(complaintData, complaintResponse);
    final phoneLine = submitted['departmentPhone']!.isNotEmpty
        ? 'Contact: ${submitted['departmentPhone']}\n'
        : '';
    final emailLine = submitted['departmentEmail']!.isNotEmpty
        ? 'Email: ${submitted['departmentEmail']}\n'
        : '';

    return '''Complaint Submitted Successfully!

Complaint ID: $complaintId
Category: ${submitted['category']}
Subcategory: ${submitted['subcategory']}
Assigned Department: ${submitted['department']}
${phoneLine}${emailLine}Priority: ${submitted['priority']}
Est. Resolution: ${submitted['slaHours']} hours

Your complaint has been saved in the backend with the real matched category and subcategory.

Track your complaint in "My Complaints" section.''';
  }

  @override
  void initState() {
    super.initState();

    // Set AI language to match app language
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final localeProvider = context.read<LocaleProvider>();
      _aiService.setAppLanguage(localeProvider.locale.languageCode);
      print(
          '🌐 AI language initialized to: ${localeProvider.locale.languageCode}');
    });

    // Show the welcome message immediately; slow storage/network work is warmed
    // after first paint so the chat page never opens blank.
    _startConversation();
    unawaited(_historyService.clearCurrentSession().then((_) {
      print('Cleared any existing session on init');
    }));
    unawaited(_aiService.warmBackendCategories());
  }

  void _openVoiceCallPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AICallScreen()),
    );
  }

  // ignore: unused_element
  void _initializeChat() {
    // Always clear current session on app start to prevent duplicates
    unawaited(_historyService.clearCurrentSession().then((_) {
      print('ðŸ§¹ Cleared any existing session on init');
    }));
    unawaited(_aiService.warmBackendCategories());
    print('🧹 Cleared any existing session on init');

    // Start fresh conversation
    _startConversation();
  }

  Future<void> _loadOrStartConversation() async {
    // Try to load current session
    final currentSession = await _historyService.loadCurrentSession();

    // Only restore if session exists, has messages, and is incomplete
    if (currentSession != null &&
        currentSession.messages.isNotEmpty &&
        !currentSession.isCompleted) {
      print(
          '📂 Restoring session: ${currentSession.id} with ${currentSession.messages.length} messages');

      // Restore previous incomplete session
      setState(() {
        _currentSessionId = currentSession.id;
        _complaintId = currentSession.complaintId;
        _messages.clear();

        for (final msgData in currentSession.messages) {
          _messages.add(ChatMessage(
            text: msgData['text'] ?? '',
            isUser: msgData['isUser'] ?? false,
            timestamp: DateTime.parse(msgData['timestamp']),
            buttons: List<String>.from(msgData['buttons'] ?? []),
            suggestions: List<String>.from(msgData['suggestions'] ?? []),
            urgencyLevel: msgData['urgencyLevel'],
            estimatedTime: msgData['estimatedTime'],
          ));
        }
      });
      _scrollToBottom();
    } else {
      // Clear any old completed session and start fresh
      if (currentSession != null && currentSession.isCompleted) {
        print('Clearing completed session');
        await _historyService.clearCurrentSession();
      }

      print('🆕 Starting fresh conversation');
      _startConversation();
    }
  }

  void _startConversation() {
    final user = context.read<AuthProvider>().user;

    // Reset AI service to ensure clean state
    _aiService.reset();

    setState(() {
      _isLoading = false;
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _complaintId = null;
      _selectedImage = null;
      _selectedProofFile = null;
      _selectedLocation = null;
      _selectedLatLng = null;
      _messages.clear(); // Clear any existing messages
    });

    print('🚀 Starting new conversation with session: $_currentSessionId');

    // Prepare user profile
    final userProfile = {
      'fullName': user?.fullName,
      'mobile': user?.mobileNo,
      'email': user?.email,
    };

    final response = _aiService.startInstantConversation(
      userName: user?.fullName ?? 'User',
      userCity: 'Smart City',
      userProfile: userProfile,
    );

    setState(() {
      _messages.add(ChatMessage(
        text: response.message,
        isUser: false,
        buttons: response.buttons,
        suggestions: response.suggestions,
        timestamp: DateTime.now(),
      ));
      _showInput = response.showInput;
      _isLoading = false;
    });

    print('✅ Conversation started with ${_messages.length} message(s)');

    _scrollToBottom();
    // Don't save immediately - wait for user interaction
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Check for special actions
    if (text.contains('📍 Use Current Location')) {
      _handleCurrentLocation();
      return;
    }

    if (text.contains('📝 Enter Full Address')) {
      setState(() {
        _messages.add(ChatMessage(
          text: '📝 Enter Full Address',
          isUser: true,
          timestamp: DateTime.now(),
        ));
      });
      _sendMessage('Type Address');
      return;
    }

    if (text.contains('📷 Take Photo')) {
      _handleTakePhoto();
      return;
    }

    if (text.contains('🖼️ Gallery') ||
        text.contains('🖼️ Choose from Gallery')) {
      _handleChooseFromGallery();
      return;
    }

    if (text.contains('Upload Video')) {
      _handleChooseVideoFromGallery();
      return;
    }

    if (_aiService.isAwaitingMediaConfirmation) {
      _handleMediaIntakeConfirmation(text);
      return;
    }

    if (_isSubmitAction(text)) {
      _handleSubmitComplaint();
      return;
    }

    // Check if this is a category button click - show subcategory dialog
    if (_shouldShowSubcategoryDialog(text)) {
      await _showSubcategoryDialogForCategory(text);
      return;
    }

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    final response = await _aiService.processInput(text);

    setState(() {
      _messages.add(ChatMessage(
        text: response.message,
        isUser: false,
        buttons: response.buttons,
        suggestions: response.suggestions,
        timestamp: DateTime.now(),
        urgencyLevel: response.urgencyLevel,
        estimatedTime: response.estimatedResolutionTime,
      ));
      _showInput = response.showInput;
      _isLoading = false;
    });

    _scrollToBottom();

    // Save session after user interaction (not on initial greeting)
    if (_messages.length > 1) {
      _saveCurrentSession();
    }
  }

  // Check if we should show subcategory dialog
  bool _shouldShowSubcategoryDialog(String text) {
    // Disabled - show subcategories as buttons in chat instead
    return false;
  }

  // Show subcategory dialog for selected category
  Future<void> _showSubcategoryDialogForCategory(String categoryButton) async {
    setState(() {
      _messages.add(ChatMessage(
        text: categoryButton,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    // Send to AI to get subcategories
    final response = await _aiService.processInput(categoryButton);

    // Extract category info
    final categoryEmoji = categoryButton.split(' ').first;
    final categoryName =
        categoryButton.substring(categoryButton.indexOf(' ') + 1);

    // Check if response has subcategories.
    final hasSubcategories = response.buttons.isNotEmpty &&
        response.buttons.length >= 3 &&
        response.buttons.every((btn) =>
            !btn.startsWith(RegExp(r'^[\p{Emoji}\s]+', unicode: true)));

    setState(() {
      _isLoading = false;
    });

    if (hasSubcategories) {
      // Show dialog instead of adding message with buttons
      await showSubcategoryDialog(
        context: context,
        categoryName: categoryName,
        categoryEmoji: categoryEmoji,
        subcategories: response.buttons,
        onSelected: (selectedSubcategory) {
          // User selected a subcategory from dialog
          _handleSubcategorySelection(selectedSubcategory);
        },
      );
      // Don't save session here - wait for subcategory selection
    } else {
      // No subcategories, show normal response
      setState(() {
        _messages.add(ChatMessage(
          text: response.message,
          isUser: false,
          buttons: response.buttons,
          suggestions: response.suggestions,
          timestamp: DateTime.now(),
          urgencyLevel: response.urgencyLevel,
          estimatedTime: response.estimatedResolutionTime,
        ));
        _showInput = response.showInput;
      });
      _scrollToBottom();

      if (_messages.length > 1) {
        _saveCurrentSession();
      }
    }
  }

  // Handle subcategory selection from dialog
  void _handleSubcategorySelection(String subcategory) {
    // Simply send the subcategory as a normal message
    _sendMessage(subcategory);
  }

  void _showMediaUploadSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                _buildMediaSheetAction(
                  icon: Icons.photo_camera_rounded,
                  title: 'Take Photo',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleTakePhoto();
                  },
                ),
                const SizedBox(height: 10),
                _buildMediaSheetAction(
                  icon: Icons.image_rounded,
                  title: 'Upload Image',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleChooseFromGallery();
                  },
                ),
                const SizedBox(height: 10),
                _buildMediaSheetAction(
                  icon: Icons.video_file_rounded,
                  title: 'Upload Video',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleChooseVideoFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaSheetAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSubmitAction(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('submit') ||
        normalized.contains('सबमिट') ||
        normalized.contains('સબમિટ') ||
        normalized.contains('sabmit');
  }

  Future<void> _handleCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          setState(() => _isLoading = false);
          return;
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Show map to confirm/adjust location with warning
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialPosition: LatLng(position.latitude, position.longitude),
            isComplaintLocation: true,
          ),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        _selectedLatLng = result['latlng'];
        _selectedLocation = result['address'];

        // Set location coordinates in AI service
        _aiService.setLocationCoordinates(
          _selectedLatLng!.latitude,
          _selectedLatLng!.longitude,
          city: result['city'],
          state: result['state'],
        );

        setState(() {
          _messages.add(ChatMessage(
            text: '📍 Location selected: $_selectedLocation',
            isUser: true,
            timestamp: DateTime.now(),
          ));
        });

        // Send location to AI (will trigger duplicate check and department assignment)
        _sendMessage(_selectedLocation!);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Failed to get location: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTakePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        await _handleSelectedMediaForAI(
          File(photo.path),
          'Photo captured',
          isVideo: false,
        );
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _handleChooseFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _handleSelectedMediaForAI(
          File(image.path),
          'Photo selected from gallery',
          isVideo: false,
        );
      }
    } catch (e) {
      _showError('Failed to select photo: $e');
    }
  }

  Future<void> _handleChooseVideoFromGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );

      if (video != null) {
        await _handleSelectedMediaForAI(
          File(video.path),
          'Video selected from gallery',
          isVideo: true,
        );
      }
    } catch (e) {
      _showError('Failed to select video: $e');
    }
  }

  Future<void> _handleSelectedMediaForAI(
    File mediaFile,
    String label, {
    required bool isVideo,
  }) async {
    setState(() {
      _selectedProofFile = mediaFile;
      _selectedImage = isVideo ? null : mediaFile;
      _messages.add(ChatMessage(
        text: label,
        isUser: true,
        timestamp: DateTime.now(),
        imageFile: isVideo ? null : mediaFile,
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    final complaintProvider = context.read<ComplaintProvider>();
    final result = await complaintProvider.analyzeMedia([mediaFile]);

    if (!mounted) return;

    final analysis = result?['analysis'];
    if (result == null || result['success'] != true || analysis is! Map) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          text: result?['message'] ??
              'I could not analyze this media. Please describe the issue in one line.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      return;
    }

    final response = _aiService.applyMediaIntakeAnalysis(
      Map<String, dynamic>.from(analysis),
      isVideo: isVideo,
    );

    setState(() {
      _isLoading = false;
      _messages.add(ChatMessage(
        text: response.message,
        isUser: false,
        buttons: response.buttons,
        suggestions: response.suggestions,
        timestamp: DateTime.now(),
      ));
      _showInput = response.showInput;
    });
    _scrollToBottom();
  }

  Future<void> _handleMediaIntakeConfirmation(String text) async {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    final normalized = text.trim().toLowerCase();
    final shouldContinue = _isSubmitAction(text) ||
        normalized.contains('yes') ||
        normalized.contains('continue');
    final response = shouldContinue
        ? _aiService.continueMediaIntake()
        : await _aiService.processInput(text);

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: response.message,
        isUser: false,
        buttons: response.buttons,
        suggestions: response.suggestions,
        timestamp: DateTime.now(),
      ));
      _showInput = response.showInput;
      _isLoading = false;
    });
    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _handleSelectedProof(File imageFile, String label) async {
    final complaintData = _aiService.getComplaintData();
    final categoryKey = (complaintData['category_key'] ?? '').toString();
    final categoryName = (complaintData['category'] ?? categoryKey).toString();
    final subcategory = (complaintData['subcategory'] ?? '').toString().trim();
    final description =
        (complaintData['description'] ?? complaintData['raw_description'] ?? '')
            .toString()
            .trim();

    setState(() {
      _messages.add(ChatMessage(
        text: label,
        isUser: true,
        timestamp: DateTime.now(),
        imageFile: imageFile,
      ));
    });
    _scrollToBottom();

    if (categoryKey.isEmpty) {
      setState(() {
        _isLoading = false;
        _selectedImage = null;
        _selectedProofFile = null;
        _messages.add(ChatMessage(
          text:
              'Please first select the complaint category before uploading proof. Gemini needs the issue type to compare your image correctly.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      return;
    }

    if (subcategory.isEmpty) {
      setState(() {
        _isLoading = false;
        _selectedImage = null;
        _selectedProofFile = null;
        _messages.add(ChatMessage(
          text:
              'Please choose the complaint type first. Gemini can verify the photo only after it knows the exact issue.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _isLoading = true;
      _messages.add(ChatMessage(
        text:
            'Verifying your uploaded proof with Gemini for **$categoryName**...',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    final complaintProvider = context.read<ComplaintProvider>();
    final verifyResult = await complaintProvider.verifyProof(
      categoryKey,
      [imageFile],
      uploadedOnly: true,
      subcategory: subcategory,
      description: description,
    );

    if (!mounted) return;

    if (verifyResult != null && verifyResult['success'] == true) {
      setState(() {
        _selectedImage = imageFile;
        _selectedProofFile = imageFile;
        _isLoading = false;
        _messages.add(ChatMessage(
          text:
              'Proof verified for **$categoryName**. Continuing with your complaint.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      _sendMessage('Photo added');
      return;
    }

    final errorMsg = verifyResult?['message'] ??
        'Invalid proof detected. Please upload the right proof or add more complaint details.';

    setState(() {
      _selectedImage = null;
      _selectedProofFile = null;
      _isLoading = false;
      _messages.add(ChatMessage(
        text: errorMsg,
        isUser: false,
        timestamp: DateTime.now(),
        buttons: const ['📷 Take Photo', '🖼️ Choose from Gallery', '⏭️ Skip'],
      ));
    });
    _scrollToBottom();
  }

  Future<void> _handleSubmitComplaint() async {
    try {
      setState(() => _isLoading = true);

      final complaintData = _aiService.getComplaintData();
      final user = context.read<AuthProvider>().user;

      if (user == null) {
        _showError('Please login to submit complaint');
        setState(() => _isLoading = false);
        return;
      }

      {
        final chatCategoryKey =
            (complaintData['category_key'] ?? '').toString();
        final chatSubcategory = (complaintData['subcategory'] ?? '').toString();
        final chatDescription = (complaintData['description'] ??
                complaintData['raw_description'] ??
                '')
            .toString();

        if (chatCategoryKey.isEmpty) {
          _showError('Category is required');
          setState(() => _isLoading = false);
          return;
        }

        if (chatSubcategory.isEmpty) {
          _showError('Subcategory is required');
          setState(() => _isLoading = false);
          return;
        }

        if (chatDescription.isEmpty) {
          _showError('Description is required');
          setState(() => _isLoading = false);
          return;
        }

        final complaintProvider = context.read<ComplaintProvider>();
        final selectedFiles =
            _selectedProofFile != null ? <File>[_selectedProofFile!] : <File>[];

        if (selectedFiles.isNotEmpty) {
          final verifyResult = await complaintProvider.verifyProof(
            chatCategoryKey,
            selectedFiles,
            uploadedOnly: true,
            subcategory: chatSubcategory,
            description: chatDescription,
          );

          if (verifyResult == null || verifyResult['success'] != true) {
            final errorMsg = verifyResult?['message'] ??
                'Invalid proof detected. Please upload the right proof or add more complaint details.';
            setState(() {
              _isLoading = false;
              _messages.add(ChatMessage(
                text: errorMsg,
                isUser: false,
                timestamp: DateTime.now(),
                buttons: const [
                  '📷 Take Photo',
                  '🖼️ Choose from Gallery',
                  '⏭️ Skip'
                ],
              ));
            });
            _scrollToBottom();
            return;
          }
        }

        final submitData = <String, String>{
          'title': '$chatSubcategory - ${complaintData['category']}',
          'description': chatDescription,
          'complaint_type': chatCategoryKey,
          'subcategory': chatSubcategory,
          'address':
              (_selectedLocation ?? complaintData['location'] ?? '').toString(),
          'latitude': (_selectedLatLng?.latitude ??
                  _readComplaintCoordinate(complaintData, 'latitude'))
              .toString(),
          'longitude': (_selectedLatLng?.longitude ??
                  _readComplaintCoordinate(complaintData, 'longitude'))
              .toString(),
          'priority': _mapAiPriorityForBackend(complaintData['priority']),
          'uploaded_only_verification': 'true',
        };
        _addIfNotEmpty(
            submitData, 'date_of_occurrence', complaintData['date_noticed']);

        if (complaintData.containsKey('contact_name') &&
            complaintData['contact_name'].toString().isNotEmpty) {
          final name = complaintData['contact_name'].toString();
          submitData['guest_name'] = name;
          submitData['name'] = name;
        }
        if (complaintData.containsKey('contact_mobile') &&
            complaintData['contact_mobile'].toString().isNotEmpty) {
          final mobile = complaintData['contact_mobile'].toString();
          submitData['guest_phone'] = mobile;
          submitData['mobile_no'] = mobile;
          submitData['preferred_contact_phone'] = 'true';
        }
        if (complaintData.containsKey('contact_email') &&
            complaintData['contact_email'].toString().isNotEmpty) {
          final email = complaintData['contact_email'].toString();
          submitData['guest_email'] = email;
          submitData['email'] = email;
          submitData['preferred_contact_email'] = 'true';
        }

        print('Submitting AI chat complaint with data: $submitData');

        final result =
            await complaintProvider.createComplaint(submitData, selectedFiles);

        if (result != null && result['success'] == true) {
          await complaintProvider.loadComplaints();
          final complaintResponse = _asStringDynamicMap(result['complaint']);
          final complaintId = complaintResponse?['complaint_number'] ??
              result['complaint_id'] ??
              'Unknown';
          final submittedDetails = _extractSubmittedComplaintDetails(
              complaintData, complaintResponse);

          complaintData['complaint_id'] = complaintId;
          complaintData['status'] = 'submitted';
          complaintData['category'] = submittedDetails['category'];
          complaintData['subcategory_display'] =
              submittedDetails['subcategory'];
          complaintData['subcategory'] = submittedDetails['subcategory'];
          complaintData['assigned_department'] = submittedDetails['department'];
          complaintData['department'] = submittedDetails['department'];
          complaintData['department_phone'] =
              submittedDetails['departmentPhone'];
          complaintData['department_email'] =
              submittedDetails['departmentEmail'];

          setState(() {
            _messages.add(ChatMessage(
              text: _buildComplaintSubmittedMessage(
                complaintData,
                complaintResponse,
                complaintId,
              ),
              isUser: false,
              timestamp: DateTime.now(),
              buttons: const ['View My Complaints', 'File Another', 'Home'],
            ));
            _isLoading = false;
          });

          _scrollToBottom();
          _complaintId = complaintId;
          await _saveCurrentSession();

          Future.delayed(const Duration(seconds: 2), () async {
            await _historyService.clearCurrentSession();
            print('Cleared completed session from current');
          });
          return;
        }

        final errorMsg = result?['message'] ??
            complaintProvider.error ??
            'Failed to submit complaint';
        print('AI chat submission failed: $errorMsg');
        _showError(errorMsg);
        setState(() => _isLoading = false);
        return;
      }

      // Upload image to Cloudinary if exists
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadToCloudinary(_selectedImage!);
        if (imageUrl == null) {
          // Ask user if they want to continue without image
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ Image Upload Failed'),
              content: const Text(
                'Failed to upload image. Would you like to:\n\n'
                '1. Try uploading again\n'
                '2. Submit complaint without image\n'
                '3. Cancel submission',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Submit Without Image'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, null);
                    _handleSubmitComplaint(); // Retry
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );

          if (shouldContinue == null) {
            // User chose to retry - function will be called again
            return;
          } else if (shouldContinue == false) {
            // User cancelled
            setState(() => _isLoading = false);
            return;
          }
          // If shouldContinue == true, continue without image
        }
      }

      // Prepare complaint data with contact details
      final categoryKey = (complaintData['category_key'] ?? '').toString();
      final subcategory = (complaintData['subcategory'] ?? '').toString();

      // Validate required fields
      if (categoryKey.isEmpty) {
        _showError('Category is required');
        setState(() => _isLoading = false);
        return;
      }

      if (subcategory.isEmpty) {
        _showError('Subcategory is required');
        setState(() => _isLoading = false);
        return;
      }

      final description = (complaintData['description'] ??
              complaintData['raw_description'] ??
              '')
          .toString();
      if (description.isEmpty) {
        _showError('Description is required');
        setState(() => _isLoading = false);
        return;
      }

      final submitData = <String, String>{
        'title': '$subcategory - ${complaintData['category']}',
        'description': description,
        'complaint_type': categoryKey, // Use complaint_type to match backend
        'subcategory': subcategory,
        'address':
            (_selectedLocation ?? complaintData['location'] ?? '').toString(),
        'latitude': (_selectedLatLng?.latitude ??
                _readComplaintCoordinate(complaintData, 'latitude'))
            .toString(),
        'longitude': (_selectedLatLng?.longitude ??
                _readComplaintCoordinate(complaintData, 'longitude'))
            .toString(),
        'priority': _mapAiPriorityForBackend(complaintData['priority']),
      };
      _addIfNotEmpty(
          submitData, 'date_of_occurrence', complaintData['date_noticed']);

      // Add contact details if available
      if (complaintData.containsKey('contact_name') &&
          complaintData['contact_name'].toString().isNotEmpty) {
        final name = complaintData['contact_name'].toString();
        submitData['guest_name'] = name;
        submitData['name'] = name;
      }
      if (complaintData.containsKey('contact_mobile') &&
          complaintData['contact_mobile'].toString().isNotEmpty) {
        final mobile = complaintData['contact_mobile'].toString();
        submitData['guest_phone'] = mobile;
        submitData['mobile_no'] = mobile;
        submitData['preferred_contact_phone'] = 'true';
      }
      if (complaintData.containsKey('contact_email') &&
          complaintData['contact_email'].toString().isNotEmpty) {
        final email = complaintData['contact_email'].toString();
        submitData['guest_email'] = email;
        submitData['email'] = email;
        submitData['preferred_contact_email'] = 'true';
      }

      // Add image URL if uploaded
      if (imageUrl != null) {
        submitData['image_url'] = imageUrl;
      }

      print('📤 Submitting complaint with data: $submitData');

      // Prepare files list (empty since we already uploaded to Cloudinary)
      final files = <File>[];

      // Submit complaint via provider
      final complaintProvider = context.read<ComplaintProvider>();
      final result = await complaintProvider.createComplaint(submitData, files);

      if (result != null && result['success'] == true) {
        await complaintProvider.loadComplaints();
        // Extract real data from backend response
        final complaintResponse = _asStringDynamicMap(result['complaint']);
        final complaintId = complaintResponse?['complaint_number'] ??
            result['complaint_id'] ??
            'Unknown';

        final submittedDetails =
            _extractSubmittedComplaintDetails(complaintData, complaintResponse);
        final matchedCategory = submittedDetails['category'] ?? 'Unknown';
        final matchedSubcategory = submittedDetails['subcategory'] ?? 'Unknown';
        final assignedDepartment =
            '${submittedDetails['department'] ?? 'Assignment in progress'}\n'
            'Matched Category: $matchedCategory\n'
            'Matched Subcategory: $matchedSubcategory';
        final departmentPhone = submittedDetails['departmentPhone'] ?? '';
        final departmentEmail = submittedDetails['departmentEmail'] ?? '';
        final priority = submittedDetails['priority'] ?? 'Normal';
        final estimatedResolution =
            '${submittedDetails['slaHours'] ?? '48'} hours';

        // Update AI with real complaint ID
        complaintData['complaint_id'] = complaintId;
        complaintData['status'] = 'submitted';
        complaintData['category'] = submittedDetails['category'];
        complaintData['subcategory_display'] = submittedDetails['subcategory'];
        complaintData['subcategory'] = submittedDetails['subcategory'];
        complaintData['assigned_department'] = submittedDetails['department'];
        complaintData['department'] = submittedDetails['department'];
        complaintData['department_phone'] = submittedDetails['departmentPhone'];
        complaintData['department_email'] = submittedDetails['departmentEmail'];

        setState(() {
          _messages.add(ChatMessage(
            text: '''🎉 **Complaint Submitted Successfully!**

**Complaint ID:** $complaintId
🏛️ **Assigned to:** $assignedDepartment
${departmentPhone.isNotEmpty ? '📞 **Contact:** $departmentPhone\n' : ''}${departmentEmail.isNotEmpty ? '📧 **Email:** $departmentEmail\n' : ''}📈 **Priority:** $priority
⏱️ **Est. Resolution:** $estimatedResolution

Your complaint has been registered and assigned to the nearest department.

✅ Track your complaint in "My Complaints" section.''',
            isUser: false,
            timestamp: DateTime.now(),
            buttons: ['View My Complaints', 'File Another', 'Home'],
          ));
          _isLoading = false;
        });

        _scrollToBottom();

        // Save complaint ID to session
        _complaintId = complaintId;
        await _saveCurrentSession(); // Save with isCompleted = true

        // Clear current session after a delay so user can see success message
        Future.delayed(const Duration(seconds: 2), () async {
          await _historyService.clearCurrentSession();
          print('🧹 Cleared completed session from current');
        });
      } else {
        final errorMsg = result?['message'] ??
            complaintProvider.error ??
            'Failed to submit complaint';
        print('❌ Submission failed: $errorMsg');
        _showError(errorMsg);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Exception during submission: $e');
      _showError('Error submitting complaint: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      setState(() {
        _messages.add(ChatMessage(
          text: '☁️ Uploading image...',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();

      const cloudName = 'dk1q50evg';
      const uploadPreset = 'smartcity_complaints';

      final url =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'complaints';

      final multipartFile =
          await http.MultipartFile.fromPath('file', imageFile.path);
      request.files.add(multipartFile);

      print('Uploading to Cloudinary: $cloudName with preset: $uploadPreset');

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
            onTimeout: () =>
                throw Exception('Upload timeout - check your connection'),
          );

      final response = await http.Response.fromStream(streamedResponse);
      print('Upload response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final imageUrl = jsonData['secure_url'] as String;
        print('Image uploaded successfully: $imageUrl');

        setState(() {
          _messages.add(ChatMessage(
            text: '✅ Image uploaded successfully!',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();

        return imageUrl;
      } else {
        final errorBody = response.body;
        print('Upload failed: ${response.statusCode} - $errorBody');
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Upload error: $e');

      setState(() {
        _messages.add(ChatMessage(
          text:
              '❌ Upload failed: ${e.toString()}\n\nPlease check your internet connection.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();

      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _copyMessageToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.black87,
        ),
      );
    } catch (e) {
      _showError('Failed to copy message');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            _buildAiAvatar(40),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  'Online',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _buildTopActionButton(
            icon: Icons.call_rounded,
            tooltip: 'Start AI call',
            onTap: _openVoiceCallPage,
            dark: true,
          ),
          const SizedBox(width: 8),
          _buildTopActionButton(
            icon: Icons.history_rounded,
            tooltip: 'Chat History',
            onTap: () => _showChatHistory(),
          ),
          const SizedBox(width: 8),
          _buildTopActionButton(
            icon: Icons.add_comment_rounded,
            tooltip: 'New Chat',
            onTap: () => _startNewChat(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index], index);
              },
            ),
          ),
          if (_isLoading) _buildTypingIndicator(),
          if (_showInput) _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAiAvatar(double size, {bool elevated = false}) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A)
                .withValues(alpha: elevated ? 0.12 : 0.06),
            blurRadius: elevated ? 32 : 18,
            offset: Offset(0, elevated ? 16 : 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.smart_toy_rounded,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool dark = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTapDown: (_) => HapticFeedback.selectionClick(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: dark ? null : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.95),
            ),
            gradient: dark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: dark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: dark ? 20 : 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 19,
            color: dark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final userBg = isDark ? const Color(0xFF050505) : const Color(0xFF111827);
    final aiTextColor = isDark ? Colors.white : const Color(0xFF111827);
    const userTextColor = Colors.white;
    final borderRadius = BorderRadius.circular(20);
    final isSelected = _selectedMessageIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                _buildAiAvatar(34),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: message.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: message.isUser
                            ? null
                            : () async {
                                setState(() {
                                  _selectedMessageIndex =
                                      _selectedMessageIndex == index
                                          ? null
                                          : index;
                                });
                                await _copyMessageToClipboard(message.text);
                              },
                        borderRadius: borderRadius,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: message.isUser ? userBg : aiBg,
                            borderRadius: borderRadius,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF111827)
                                  : Colors.white.withValues(alpha: 0.95),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormattedText(
                                message.text,
                                message.isUser,
                                message.isUser ? userTextColor : aiTextColor,
                              ),
                              if (!message.isUser) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Tap to copy',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black45,
                                  ),
                                ),
                              ],
                              if (message.urgencyLevel != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _getUrgencyColor(message.urgencyLevel!),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '⚠️ ${message.urgencyLevel}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                              if (message.estimatedTime != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '⏱️ Est. Resolution: ${message.estimatedTime}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: message.isUser
                                        ? Colors.white70
                                        : const Color(0xFF64748b),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (message.imageFile != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          message.imageFile!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (message.isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.95)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF111827),
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
          if (!message.isUser && message.buttons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.buttons.map((button) {
                return _buildButton(button);
              }).toList(),
            ),
          ],
          // suggestion chips removed
        ],
      ),
    );
  }

  Widget _buildButton(String text) {
    // Handle navigation buttons
    if (text.contains('View My Complaints') || text.contains('My Complaints')) {
      return GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.userTrack),
        child: _buttonContainer(text),
      );
    }

    if (text.contains('Home')) {
      return GestureDetector(
        onTap: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.userDashboard,
          (route) => false,
        ),
        child: _buttonContainer(text),
      );
    }

    if (text.contains('File Another') || text.contains('➕ New Complaint')) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _messages.clear();
            _aiService.reset();
            _selectedImage = null;
            _selectedProofFile = null;
            _selectedLocation = null;
            _selectedLatLng = null;
          });
          _startConversation();
        },
        child: _buttonContainer(text),
      );
    }

    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: _buttonContainer(text),
    );
  }

  Widget _buttonContainer(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }

  // suggestions removed per user request

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildAiAvatar(34),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Opacity(
          opacity: (value + index * 0.3) % 1.0,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTapDown: (_) => HapticFeedback.selectionClick(),
              onTap: _showMediaUploadSheet,
              child: Container(
                width: 48,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.025),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Color(0xFF111827),
                  size: 23,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.025),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: TextSelectionTheme(
                  data: const TextSelectionThemeData(
                    cursorColor: Color(0xFF111827),
                    selectionColor: Color(0x22111827),
                    selectionHandleColor: Color(0xFF111827),
                  ),
                  child: TextField(
                    controller: _messageController,
                    cursorColor: const Color(0xFF111827),
                    decoration: InputDecoration(
                      isCollapsed: false,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Type your message...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTapDown: (_) => HapticFeedback.selectionClick(),
              onTap: () => _sendMessage(_messageController.text),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
                  ),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getUrgencyColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF97316);
      case 'medium':
        return const Color(0xFFEAB308);
      default:
        return const Color(0xFF22C55E);
    }
  }

  Future<void> _saveCurrentSession() async {
    if (_messages.isEmpty || _currentSessionId == null) return;

    final messagesData = _messages
        .map((msg) => {
              'text': msg.text,
              'isUser': msg.isUser,
              'timestamp': msg.timestamp.toIso8601String(),
              'buttons': msg.buttons,
              'suggestions': msg.suggestions,
              'urgencyLevel': msg.urgencyLevel,
              'estimatedTime': msg.estimatedTime,
            })
        .toList();

    final session = ChatSession(
      id: _currentSessionId!,
      title: _historyService.generateChatTitle(messagesData),
      createdAt: _messages.first.timestamp,
      lastMessageAt: _messages.last.timestamp,
      messages: messagesData,
      complaintId: _complaintId,
      isCompleted:
          _complaintId != null, // Mark as completed if complaint submitted
    );

    await _historyService.saveCurrentSession(session);
    print('💾 Saved session: ${session.id}, completed: ${session.isCompleted}');
  }

  Widget _buildFormattedText(String text, bool isUser, Color textColor) {
    final parts = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        parts.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: textColor,
            height: 1.5,
          ),
        ));
      }

      parts.add(TextSpan(
        text: match.group(1),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1.5,
        ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      parts.add(TextSpan(
        text: text.substring(lastIndex),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: textColor,
          height: 1.5,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: parts),
    );
  }

  Future<void> _startNewChat() async {
    // Save current chat to history only if it has messages and is incomplete
    if (_messages.isNotEmpty && _complaintId == null) {
      await _saveCurrentSession();
      final currentSession = await _historyService.loadCurrentSession();
      if (currentSession != null) {
        await _historyService.saveSession(currentSession);
      }
    }

    // Clear current session
    await _historyService.clearCurrentSession();

    // Reset state
    setState(() {
      _messages.clear();
      _selectedImage = null;
      _selectedProofFile = null;
      _selectedLocation = null;
      _selectedLatLng = null;
      _currentSessionId = null;
      _complaintId = null;
    });

    // Reset AI service
    _aiService.reset();

    // Start new conversation
    _startConversation();
  }

  Future<void> _showChatHistory() async {
    // Save current session before showing history
    await _saveCurrentSession();

    final selectedSession = await Navigator.push<ChatSession>(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatHistoryScreen(),
      ),
    );

    if (selectedSession != null) {
      // Load selected session
      setState(() {
        _currentSessionId = selectedSession.id;
        _complaintId = selectedSession.complaintId;
        _messages.clear();

        for (final msgData in selectedSession.messages) {
          _messages.add(ChatMessage(
            text: msgData['text'] ?? '',
            isUser: msgData['isUser'] ?? false,
            timestamp: DateTime.parse(msgData['timestamp']),
            buttons: List<String>.from(msgData['buttons'] ?? []),
            suggestions: List<String>.from(msgData['suggestions'] ?? []),
            urgencyLevel: msgData['urgencyLevel'],
            estimatedTime: msgData['estimatedTime'],
          ));
        }
      });

      // Save as current session
      await _historyService.saveCurrentSession(selectedSession);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    // Only save if user has interacted (more than just greeting message)
    if (_messages.length > 1 && _complaintId == null) {
      print('💾 Saving incomplete session on dispose');
      _saveCurrentSession();
    } else if (_complaintId != null) {
      print('✅ Complaint submitted, session already saved');
    } else {
      print('🚫 Not saving - only greeting message');
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> buttons;
  final List<String> suggestions;
  final DateTime timestamp;
  final String? urgencyLevel;
  final String? estimatedTime;
  final File? imageFile;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.buttons = const [],
    this.suggestions = const [],
    required this.timestamp,
    this.urgencyLevel,
    this.estimatedTime,
    this.imageFile,
  });
}

// Location Picker Screen with Leaflet Map
class LocationPickerScreen extends StatefulWidget {
  final LatLng initialPosition;
  final bool isComplaintLocation;

  const LocationPickerScreen({
    Key? key,
    required this.initialPosition,
    this.isComplaintLocation = false,
  }) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _selectedPosition;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isComplaintLocation
              ? 'Select Complaint Location'
              : 'Select Location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E66F5),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {
                'latlng': _selectedPosition,
                'address':
                    'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}, Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _selectedPosition,
              zoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPosition = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartcity.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPosition,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_pin,
                      size: 50,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.isComplaintLocation)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2F80ED), width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: const Color(0xFF2F80ED), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Select the complaint/incident location, NOT your personal address',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0B1020),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tap on map to select location',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}\nLng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748b),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Position position = await Geolocator.getCurrentPosition();
          setState(() {
            _selectedPosition = LatLng(position.latitude, position.longitude);
          });
          _mapController.move(_selectedPosition, 15.0);
        },
        backgroundColor: const Color(0xFF1E66F5),
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
