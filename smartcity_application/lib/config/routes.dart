import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/complaints/category_selection_screen.dart';
import '../screens/complaints/submit_complaint_screen.dart';
import '../screens/complaints/track_complaints_screen.dart';
import '../screens/complaints/guest_track_screen.dart';
import '../screens/complaints/complaint_detail_screen.dart';
import '../screens/complaints/complaint_success_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/dashboard/guest_dashboard_screen.dart';
import '../screens/dashboard/user_dashboard_screen.dart';
import '../screens/complaints/user_track.dart';
import '../screens/departments/departments_list_screen.dart';
import '../screens/departments/departments_by_category_screen.dart';
import '../screens/departments/department_detail_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String userDashboard = '/user-dashboard';
  static const String guestDashboard = '/guest-dashboard';
  static const String departmentsList = '/departments-list';
  static const String departmentsByCategory = '/departments-by-category';
  static const String departmentDetail = '/department-detail';
  static const String categorySelection = '/category-selection';
  static const String submitComplaint = '/submit-complaint';
  static const String trackComplaints = '/track-complaints';
  static const String userTrack = '/user-track';
  static const String guestTrack = '/guest-track';
  static const String complaintDetail = '/complaint-detail';
  static const String complaintSuccess = '/complaint-success';
  static const String profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case otp:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => OtpScreen(email: args?['email'] ?? ''),
        );
      
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      
      case dashboard:
      case userDashboard:
        return MaterialPageRoute(builder: (_) => const UserDashboardScreen());

      case guestDashboard:
        return MaterialPageRoute(builder: (_) => const GuestDashboardScreen());

      case departmentsList:
        return MaterialPageRoute(builder: (_) => const DepartmentsListScreen());

      case departmentsByCategory:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DepartmentsByCategoryScreen(
            categoryKey: args?['key'] ?? 'other',
            categoryName: args?['name'] ?? 'Department',
            categoryEmoji: args?['emoji'] ?? '🏢',
            categoryBg: args?['bg'] as Color? ?? const Color(0xFFF8FAFC),
          ),
        );

      case departmentDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DepartmentDetailScreen(department: args ?? {}),
        );
      
      case categorySelection:
        return MaterialPageRoute(builder: (_) => const CategorySelectionScreen());
      
      case submitComplaint:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => SubmitComplaintScreen(
            categoryKey: args?['categoryKey'],
            categoryName: args?['categoryName'],
          ),
        );
      
      case guestTrack:
        return MaterialPageRoute(builder: (_) => const GuestTrackScreen());
      
      case trackComplaints:
        return MaterialPageRoute(builder: (_) => const TrackComplaintsScreen());
      
      case userTrack:
        return MaterialPageRoute(builder: (_) => const UserTrackScreen());
      
      case complaintDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ComplaintDetailScreen(
            complaintId: args?['complaintId'] ?? 0,
          ),
        );
      
      case complaintSuccess:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ComplaintSuccessScreen(
            complaintId: args?['complaintId'] ?? '',
            title: args?['title'] ?? '',
            description: args?['description'] ?? '',
          ),
        );
      
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
