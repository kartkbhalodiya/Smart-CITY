import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/complaints/category_selection_screen.dart';
import '../screens/complaints/submit_complaint_screen.dart';
import '../screens/complaints/track_complaints_screen.dart';
import '../screens/complaints/guest_track_screen.dart';
import '../screens/complaints/complaint_detail_screen.dart';
import '../screens/profile/profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String categorySelection = '/category-selection';
  static const String submitComplaint = '/submit-complaint';
  static const String trackComplaints = '/track-complaints';
  static const String guestTrack = '/guest-track';
  static const String complaintDetail = '/complaint-detail';
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
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      
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
      
      case complaintDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ComplaintDetailScreen(
            complaintId: args?['complaintId'] ?? 0,
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
