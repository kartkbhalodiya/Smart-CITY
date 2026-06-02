class ApiConfig {
  // Base URL - Production API
  static const String baseUrl = 'https://janhelps.in/api';

  // For local testing, uncomment the line below and comment the production URL above:
  // static const String baseUrl = 'http://10.0.2.2:8000/api';

  // For Android Emulator use: http://10.0.2.2:8000/api
  // For iOS Simulator use: http://127.0.0.1:8000/api
  // For Real Device use: http://YOUR_IP:8000/api (e.g., http://192.168.1.100:8000/api)

  // Authentication Endpoints
  static const String sendOtp = '$baseUrl/auth/send-otp/';
  static const String verifyOtp = '$baseUrl/auth/verify-otp/';
  static const String login = '$baseUrl/auth/login/';
  static const String register = '$baseUrl/auth/register/';
  static const String logout = '$baseUrl/auth/logout/';

  // User Endpoints
  static const String userProfile = '$baseUrl/user/profile/';

  // Dashboard Endpoints
  static const String dashboardStats = '$baseUrl/dashboard/stats/';
  static const String superAdminOverview = '$baseUrl/admin/super/overview/';
  static const String cityAdminOverview = '$baseUrl/admin/city/overview/';
  static const String departmentAdminOverview =
      '$baseUrl/admin/department/overview/';
  static String adminResource(String resource) =>
      '$baseUrl/admin/mobile/$resource/';
  static String adminResourceDetail(String resource, int id) =>
      '$baseUrl/admin/mobile/$resource/$id/';
  static String adminComplaintStatus(int id) =>
      '$baseUrl/admin/mobile/complaints/$id/status/';
  static String adminDepartmentDetail(int id) =>
      '$baseUrl/admin/mobile/departments/$id/detail/';
  static String adminCitizenDetail(int id) =>
      '$baseUrl/admin/mobile/citizens/$id/detail/';
  static const String adminHeatmap = '$baseUrl/admin/mobile/heatmap/';
  static const String adminChangePassword = '$baseUrl/admin/mobile/password/';

  // Complaint Endpoints
  static const String complaints = '$baseUrl/complaints/';
  static String complaintDetail(int id) => '$baseUrl/complaints/$id/';
  static String rateComplaint(int id) => '$baseUrl/complaints/$id/rate/';
  static String reopenComplaint(int id) => '$baseUrl/complaints/$id/reopen/';
  static const String verifyProof = '$baseUrl/complaints/verify-proof/';

  // Category Endpoints
  static const String categories = '$baseUrl/categories/';
  static String subcategories(String categoryKey) =>
      '$baseUrl/categories/$categoryKey/subcategories/';

  // Department Endpoints
  static const String departments = '$baseUrl/departments/';

  // Guest Track
  static const String trackGuest = '$baseUrl/track-guest/';

  // Department Forgot Password
  static const String departmentForgotPassword =
      '$baseUrl/auth/department-forgot-password/';

  // Guest Stats (public)
  static const String guestStats = '$baseUrl/guest/stats/';

  // States & Cities
  static const String statesCities = '$baseUrl/states-cities/';

  // AI Assistant
  static const String aiChat = '$baseUrl/ai/chat/';
  static const String aiNudge = '$baseUrl/ai/nudge/';
  static const String aiExtractComplaint = '$baseUrl/ai/extract-complaint/';
  static const String aiVoiceChat = '$baseUrl/ai/voice-chat/';
  static const String aiHistory = '$baseUrl/ai/history/';
  static const String aiReset = '$baseUrl/ai/reset/';
  static const String aiCheckDuplicate = '$baseUrl/ai/check-duplicate/';
  static const String aiGetDepartment = '$baseUrl/ai/get-department/';
  static const String mlVoiceProcess = '$baseUrl/ml-voice/process/';
  static const String mlVoiceIntakeAnalyze =
      '$baseUrl/ml-voice/intake-analyze/';
  static const String mlVoiceEmotion = '$baseUrl/ml-voice/emotion/';
  static const String mlVoiceResolveDate = '$baseUrl/ml-voice/resolve-date/';
  static String mlVoiceSession(String sessionId) =>
      '$baseUrl/ml-voice/session/$sessionId/';
  static String mlVoiceResetSession(String sessionId) =>
      '$baseUrl/ml-voice/session/$sessionId/reset/';
  static const String mlVoiceGenerateResponse =
      '$baseUrl/ml-voice/generate-response/';

  // Cloudinary
  static const String cloudinarySignature = '$baseUrl/cloudinary/signature/';

  // Timeout durations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 60);
}
