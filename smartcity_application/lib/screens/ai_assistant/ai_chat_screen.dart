import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../../services/conversational_ai_service.dart';
import '../../services/chat_history_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/locale_provider.dart';
import '../../config/routes.dart';
import 'chat_history_screen.dart';
import 'voice_call_screen.dart';

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
  bool _isLoading = false;
  bool _showInput = true;
  File? _selectedImage;
  String? _selectedLocation;
  LatLng? _selectedLatLng;
  String? _currentSessionId;
  String? _complaintId;

  @override
  void initState() {
    super.initState();
    
    // Set AI language to match app language
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final localeProvider = context.read<LocaleProvider>();
      _aiService.setAppLanguage(localeProvider.locale.languageCode);
      print('🌐 AI language initialized to: ${localeProvider.locale.languageCode}');
    });
    
    // Clear any existing session first, then load
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Always clear current session on app start to prevent duplicates
    await _historyService.clearCurrentSession();
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
      
      print('📂 Restoring session: ${currentSession.id} with ${currentSession.messages.length} messages');
      
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
        print('🗑️ Clearing completed session');
        await _historyService.clearCurrentSession();
      }
      
      print('🆕 Starting fresh conversation');
      _startConversation();
    }
  }

  void _startConversation() async {
    final user = context.read<AuthProvider>().user;
    
    // Reset AI service to ensure clean state
    _aiService.reset();
    
    setState(() {
      _isLoading = true;
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _complaintId = null;
      _messages.clear(); // Clear any existing messages
    });
    
    print('🚀 Starting new conversation with session: $_currentSessionId');
    
    // Prepare user profile
    final userProfile = {
      'fullName': user?.fullName,
      'mobile': null,
      'email': user?.email,
    };
    
    final response = await _aiService.processInput(
      'Hello',
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
    
    if (text.contains('🖼️ Gallery') || text.contains('🖼️ Choose from Gallery')) {
      _handleChooseFromGallery();
      return;
    }
    
    if (text.contains('✅ Submit')) {
      _handleSubmitComplaint();
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
        await _handleSelectedProof(File(photo.path), 'Photo captured');
        return;
        setState(() {
          _selectedImage = File(photo.path);
          _messages.add(ChatMessage(
            text: '📷 Photo captured',
            isUser: true,
            timestamp: DateTime.now(),
            imageFile: _selectedImage,
          ));
        });
        
        _sendMessage('Photo added');
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
        await _handleSelectedProof(File(image.path), 'Photo selected from gallery');
        return;
        setState(() {
          _selectedImage = File(image.path);
          _messages.add(ChatMessage(
            text: '🖼️ Photo selected from gallery',
            isUser: true,
            timestamp: DateTime.now(),
            imageFile: _selectedImage,
          ));
        });
        
        _sendMessage('Photo added');
      }
    } catch (e) {
      _showError('Failed to select photo: $e');
    }
  }

  Future<void> _handleSelectedProof(File imageFile, String label) async {
    final complaintData = _aiService.getComplaintData();
    final categoryKey = (complaintData['category_key'] ?? '').toString();
    final categoryName = (complaintData['category'] ?? categoryKey).toString();
    final subcategory = (complaintData['subcategory'] ?? '').toString().trim();
    final description =
        (complaintData['description'] ?? complaintData['raw_description'] ?? '').toString().trim();

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
        text: 'Verifying your uploaded proof with Gemini for **$categoryName**...',
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
        _isLoading = false;
        _messages.add(ChatMessage(
          text: 'Proof verified for **$categoryName**. Continuing with your complaint.',
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
        final chatCategoryKey = (complaintData['category_key'] ?? '').toString();
        final chatSubcategory = (complaintData['subcategory'] ?? '').toString();
        final chatDescription =
            (complaintData['description'] ?? complaintData['raw_description'] ?? '').toString();

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
        final selectedFiles = _selectedImage != null ? <File>[_selectedImage!] : <File>[];

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
                buttons: const ['📷 Take Photo', '🖼️ Choose from Gallery', '⏭️ Skip'],
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
          'location': (_selectedLocation ?? complaintData['location'] ?? '').toString(),
          'latitude': (_selectedLatLng?.latitude ?? complaintData['latitude'] ?? 0.0).toString(),
          'longitude': (_selectedLatLng?.longitude ?? complaintData['longitude'] ?? 0.0).toString(),
          'priority': (complaintData['priority'] ?? 'normal').toString().toLowerCase(),
          'date_noticed': (complaintData['date_noticed'] ?? '').toString(),
          'uploaded_only_verification': 'true',
        };

        if (complaintData.containsKey('contact_name') &&
            complaintData['contact_name'].toString().isNotEmpty) {
          submitData['contact_name'] = complaintData['contact_name'].toString();
        }
        if (complaintData.containsKey('contact_mobile') &&
            complaintData['contact_mobile'].toString().isNotEmpty) {
          submitData['contact_mobile'] = complaintData['contact_mobile'].toString();
        }
        if (complaintData.containsKey('contact_email') &&
            complaintData['contact_email'].toString().isNotEmpty) {
          submitData['contact_email'] = complaintData['contact_email'].toString();
        }

        print('Submitting AI chat complaint with data: $submitData');

        final result = await complaintProvider.createComplaint(submitData, selectedFiles);

        if (result != null && result['success'] == true) {
          final complaintResponse = result['complaint'] as Map<String, dynamic>?;
          final complaintId =
              complaintResponse?['complaint_number'] ?? result['complaint_id'] ?? 'Unknown';
          final departmentData =
              complaintResponse?['assigned_department'] as Map<String, dynamic>?;
          final assignedDepartment = departmentData?['name'] ?? 'Municipal Corporation';
          final departmentPhone = departmentData?['phone'] ?? '';
          final departmentEmail = departmentData?['email'] ?? '';
          final slaHours = departmentData?['sla_hours'] ?? 48;
          final priority =
              complaintResponse?['priority_display'] ?? complaintData['priority'] ?? 'Normal';
          final estimatedResolution = '$slaHours hours';

          complaintData['complaint_id'] = complaintId;
          complaintData['status'] = 'submitted';
          complaintData['department'] = assignedDepartment;

          setState(() {
            _messages.add(ChatMessage(
              text: '''Complaint Submitted Successfully!

Complaint ID: $complaintId
Assigned to: $assignedDepartment
${departmentPhone.isNotEmpty ? 'Contact: $departmentPhone\n' : ''}${departmentEmail.isNotEmpty ? 'Email: $departmentEmail\n' : ''}Priority: $priority
Est. Resolution: $estimatedResolution

Your complaint has been registered and assigned to the nearest department.

Track your complaint in "My Complaints" section.''',
              isUser: false,
              timestamp: DateTime.now(),
              buttons: const ['📋 View My Complaints', '➕ File Another', '🏠 Home'],
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

        final errorMsg =
            result?['message'] ?? complaintProvider.error ?? 'Failed to submit complaint';
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
      
      final description = (complaintData['description'] ?? complaintData['raw_description'] ?? '').toString();
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
        'location': (_selectedLocation ?? complaintData['location'] ?? '').toString(),
        'latitude': (_selectedLatLng?.latitude ?? 0.0).toString(),
        'longitude': (_selectedLatLng?.longitude ?? 0.0).toString(),
        'priority': (complaintData['priority'] ?? 'normal').toString().toLowerCase(),
        'date_noticed': (complaintData['date_noticed'] ?? '').toString(),
      };
      
      // Add contact details if available
      if (complaintData.containsKey('contact_name') && complaintData['contact_name'].toString().isNotEmpty) {
        submitData['contact_name'] = complaintData['contact_name'].toString();
      }
      if (complaintData.containsKey('contact_mobile') && complaintData['contact_mobile'].toString().isNotEmpty) {
        submitData['contact_mobile'] = complaintData['contact_mobile'].toString();
      }
      if (complaintData.containsKey('contact_email') && complaintData['contact_email'].toString().isNotEmpty) {
        submitData['contact_email'] = complaintData['contact_email'].toString();
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
        // Extract real data from backend response
        final complaintResponse = result['complaint'] as Map<String, dynamic>?;
        final complaintId = complaintResponse?['complaint_number'] ?? result['complaint_id'] ?? 'Unknown';
        
        // Get real department info from backend
        final departmentData = complaintResponse?['assigned_department'] as Map<String, dynamic>?;
        final assignedDepartment = departmentData?['name'] ?? 'Municipal Corporation';
        final departmentPhone = departmentData?['phone'] ?? '';
        final departmentEmail = departmentData?['email'] ?? '';
        final slaHours = departmentData?['sla_hours'] ?? 48;
        
        // Get priority from response
        final priority = complaintResponse?['priority_display'] ?? complaintData['priority'] ?? 'Normal';
        
        // Calculate estimated resolution time
        final estimatedResolution = '$slaHours hours';
        
        // Update AI with real complaint ID
        complaintData['complaint_id'] = complaintId;
        complaintData['status'] = 'submitted';
        complaintData['department'] = assignedDepartment;
        
        setState(() {
          _messages.add(ChatMessage(
            text: '''🎉 **Complaint Submitted Successfully!**

📋 **Complaint ID:** $complaintId
🏛️ **Assigned to:** $assignedDepartment
${departmentPhone.isNotEmpty ? '📞 **Contact:** $departmentPhone\n' : ''}${departmentEmail.isNotEmpty ? '📧 **Email:** $departmentEmail\n' : ''}📈 **Priority:** $priority
⏱️ **Est. Resolution:** $estimatedResolution

Your complaint has been registered and assigned to the nearest department.

✅ Track your complaint in "My Complaints" section.''',
            isUser: false,
            timestamp: DateTime.now(),
            buttons: ['📋 View My Complaints', '➕ File Another', '🏠 Home'],
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
        final errorMsg = result?['message'] ?? complaintProvider.error ?? 'Failed to submit complaint';
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
      
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url);
      
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'complaints';
      
      final multipartFile = await http.MultipartFile.fromPath('file', imageFile.path);
      request.files.add(multipartFile);
      
      print('Uploading to Cloudinary: $cloudName with preset: $uploadPreset');
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Upload timeout - check your connection'),
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
          text: '❌ Upload failed: ${e.toString()}\n\nPlease check your internet connection.',
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

  /// Open voice call screen
  Future<void> _openVoiceCall() async {
    final user = context.read<AuthProvider>().user;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          aiService: _aiService,
          userName: user?.fullName ?? 'User',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0f172a)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0f172a),
                  ),
                ),
                Text(
                  'Online',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Voice Call Button
          IconButton(
            icon: const Icon(Icons.phone, color: Color(0xFF64748b)),
            tooltip: 'Start Voice Call',
            onPressed: () => _openVoiceCall(),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF64748b)),
            tooltip: 'Chat History',
            onPressed: () => _showChatHistory(),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment, color: Color(0xFF64748b)),
            tooltip: 'New Chat',
            onPressed: () => _startNewChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          if (_isLoading) _buildTypingIndicator(),
          if (_showInput) _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser) ...[ 
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? const Color(0xFF1E66F5)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormattedText(
                            message.text,
                            message.isUser,
                          ),
                          if (message.urgencyLevel != null) ...[ 
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getUrgencyColor(message.urgencyLevel!),
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
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E66F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 18),
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
          if (!message.isUser && message.suggestions.isNotEmpty) ...[ 
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.suggestions.map((suggestion) {
                return _buildSuggestion(suggestion);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButton(String text) {
    // Handle navigation buttons
    if (text.contains('📋 View My Complaints') || text.contains('📋 My Complaints')) {
      return GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.userTrack),
        child: _buttonContainer(text),
      );
    }
    
    if (text.contains('🏠 Home')) {
      return GestureDetector(
        onTap: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.userDashboard,
          (route) => false,
        ),
        child: _buttonContainer(text),
      );
    }
    
    if (text.contains('➕ File Another') || text.contains('➕ New Complaint')) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _messages.clear();
            _aiService.reset();
            _selectedImage = null;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E66F5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E66F5).withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSuggestion(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.yellow.shade700),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'its just example',
            style: GoogleFonts.inter(
              fontSize: 8,
              color: Colors.red.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
              color: Color(0xFF64748b),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF0f172a),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _sendMessage(_messageController.text),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.purple.shade400],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
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

    final messagesData = _messages.map((msg) => {
      'text': msg.text,
      'isUser': msg.isUser,
      'timestamp': msg.timestamp.toIso8601String(),
      'buttons': msg.buttons,
      'suggestions': msg.suggestions,
      'urgencyLevel': msg.urgencyLevel,
      'estimatedTime': msg.estimatedTime,
    }).toList();

    final session = ChatSession(
      id: _currentSessionId!,
      title: _historyService.generateChatTitle(messagesData),
      createdAt: _messages.first.timestamp,
      lastMessageAt: _messages.last.timestamp,
      messages: messagesData,
      complaintId: _complaintId,
      isCompleted: _complaintId != null, // Mark as completed if complaint submitted
    );

    await _historyService.saveCurrentSession(session);
    print('💾 Saved session: ${session.id}, completed: ${session.isCompleted}');
  }

  Widget _buildFormattedText(String text, bool isUser) {
    final parts = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      // Add normal text before bold
      if (match.start > lastIndex) {
        parts.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isUser ? Colors.white : const Color(0xFF0f172a),
            height: 1.5,
          ),
        ));
      }

      // Add bold text
      parts.add(TextSpan(
        text: match.group(1),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isUser ? Colors.white : const Color(0xFF0f172a),
          height: 1.5,
        ),
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      parts.add(TextSpan(
        text: text.substring(lastIndex),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isUser ? Colors.white : const Color(0xFF0f172a),
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
          widget.isComplaintLocation ? 'Select Complaint Location' : 'Select Location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E66F5),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {
                'latlng': _selectedPosition,
                'address': 'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}, Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
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
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Select the complaint/incident location, NOT your personal address',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
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
