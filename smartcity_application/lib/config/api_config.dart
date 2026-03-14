class ApiConfig {
  // Base URL - Change this to your server URL
  static const String baseUrl = 'https://janhelp.vercel.app/api';
  
  // For Android Emulator use: http://10.0.2.2:8000/api
  // For iOS Simulator use: http://127.0.0.1:8000/api
  // For Real Device use: http://YOUR_IP:8000/api (e.g., http://192.168.1.100:8000/api)
  
  // Authentication Endpoints
  static const String sendOtp = '$baseUrl/auth/send-otp/';
  static const String verifyOtp = '$baseUrl/auth/verify-otp/';
  static const String register = '$baseUrl/auth/register/';
  static const String logout = '$baseUrl/auth/logout/';
  
  // User Endpoints
  static const String userProfile = '$baseUrl/user/profile/';
  
  // Dashboard Endpoints
  static const String dashboardStats = '$baseUrl/dashboard/stats/';
  
  // Complaint Endpoints
  static const String complaints = '$baseUrl/complaints/';
  static String complaintDetail(int id) => '$baseUrl/complaints/$id/';
  static String rateComplaint(int id) => '$baseUrl/complaints/$id/rate/';
  static String reopenComplaint(int id) => '$baseUrl/complaints/$id/reopen/';
  
  // Category Endpoints
  static const String categories = '$baseUrl/categories/';
  static String subcategories(String categoryKey) => 
      '$baseUrl/categories/$categoryKey/subcategories/';
  
  // Department Endpoints
  static const String departments = '$baseUrl/departments/';
  
  // Guest Track
  static const String trackGuest = '$baseUrl/track-guest/';

  // Department Forgot Password
  static const String departmentForgotPassword = '$baseUrl/auth/department-forgot-password/';
  
  // Timeout durations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
