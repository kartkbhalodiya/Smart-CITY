import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../screens/ai_assistant/ai_chat_screen.dart';
import '../screens/admin/admin_complaint_detail_screen.dart';
import '../screens/admin/admin_entity_detail_screen.dart';
import '../screens/admin/admin_heatmap_screen.dart';
import '../screens/admin/admin_location_map_screen.dart';
import '../screens/admin/admin_overview_screen.dart';
import '../screens/admin/admin_password_screen.dart';
import '../screens/admin/admin_resource_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/complaints/complaint_detail_screen.dart';
import '../screens/complaints/complaint_success_screen.dart';
import '../screens/complaints/guest_track_screen.dart';
import '../screens/complaints/submit_complaint_screen.dart';
import '../screens/complaints/user_track.dart';
import '../screens/dashboard/choose_category_modern_screen.dart';
import '../screens/dashboard/guest_dashboard_screen.dart';
import '../screens/dashboard/modern_dashboard_screen.dart';
import '../screens/dashboard/modern_home_screen.dart';
import '../screens/departments/department_detail_screen.dart';
import '../screens/departments/departments_by_category_screen.dart';
import '../screens/departments/departments_list_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String userDashboard = '/user-dashboard';
  static const String superAdminDashboard = '/admin/super-dashboard';
  static const String cityAdminDashboard = '/admin/city-dashboard';
  static const String departmentAdminDashboard = '/admin/department-dashboard';
  static const String adminResource = '/admin/resource';
  static const String adminComplaintDetail = '/admin/complaint-detail';
  static const String adminDepartmentDetail = '/admin/department-detail';
  static const String adminCitizenDetail = '/admin/citizen-detail';
  static const String adminHeatmap = '/admin/heatmap';
  static const String adminLocationMap = '/admin/location-map';
  static const String adminPassword = '/admin/password';
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
  static const String aiChat = '/ai-chat';
  static const String modernDashboard = '/modern-dashboard';
  static const String chooseCategoryModern = '/choose-category-modern';
  static const String statsScreen = '/stats-screen';
  static const String modernHome = '/modern-home';

  static String dashboardForRole(String? role) {
    switch ((role ?? 'citizen').trim().toLowerCase()) {
      case 'superadmin':
        return superAdminDashboard;
      case 'city_admin':
        return cityAdminDashboard;
      case 'department':
        return departmentAdminDashboard;
      default:
        return userDashboard;
    }
  }

  static Route<T> smoothRoute<T>(
    RouteSettings settings,
    WidgetBuilder builder,
  ) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, animation, secondaryAnimation) {
        return RepaintBoundary(child: builder(context));
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutExpo,
          reverseCurve: Curves.easeInCubic,
        );
        final fade = Tween<double>(begin: 0, end: 1).animate(curved);
        final scale = Tween<double>(begin: 0.985, end: 1).animate(curved);
        final yOffset = Tween<double>(begin: 20, end: 0).animate(curved);

        return FadeTransition(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, yOffset.value),
            child: Transform.scale(
              scale: scale.value,
              child: child,
            ),
          ),
        );
      },
    );
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return smoothRoute(settings, (_) => const SplashScreen());

      case login:
        return smoothRoute(settings, (_) => const LoginScreen());

      case otp:
        final args = settings.arguments as Map<String, dynamic>?;
        return smoothRoute(
          settings,
          (_) => OtpScreen(email: args?['email'] ?? ''),
        );

      case register:
        return smoothRoute(settings, (_) => const RegisterScreen());

      case forgotPassword:
        return smoothRoute(settings, (_) => const ForgotPasswordScreen());

      case dashboard:
      case userDashboard:
        return smoothRoute(settings, (_) => const ModernHomeScreen());

      case superAdminDashboard:
        return smoothRoute(settings, (_) => const SuperAdminDashboardScreen());

      case cityAdminDashboard:
        return smoothRoute(settings, (_) => const CityAdminDashboardScreen());

      case departmentAdminDashboard:
        return smoothRoute(
          settings,
          (_) => const DepartmentAdminDashboardScreen(),
        );

      case adminResource:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return smoothRoute(
          settings,
          (_) => AdminResourceScreen(
            resource: args['resource']?.toString() ?? 'complaints',
            title: args['title']?.toString() ?? 'Admin',
            workStatus: args['workStatus']?.toString(),
          ),
        );

      case adminComplaintDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return smoothRoute(
          settings,
          (_) => AdminComplaintDetailScreen(
            complaintId: args['complaintId'] as int? ?? 0,
          ),
        );

      case adminDepartmentDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return smoothRoute(
          settings,
          (_) => AdminDepartmentDetailScreen(
            departmentId: args['departmentId'] as int? ?? 0,
          ),
        );

      case adminCitizenDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return smoothRoute(
          settings,
          (_) => AdminCitizenDetailScreen(
            citizenId: args['citizenId'] as int? ?? 0,
          ),
        );

      case adminHeatmap:
        return smoothRoute(settings, (_) => const AdminHeatmapScreen());

      case adminLocationMap:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final rawId = args['id'];
        final id =
            rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
        return smoothRoute(
          settings,
          (_) => AdminLocationMapScreen(
            type: args['type']?.toString() ?? 'complaint',
            id: id,
          ),
        );

      case adminPassword:
        return smoothRoute(settings, (_) => const AdminPasswordScreen());

      case guestDashboard:
        return smoothRoute(settings, (_) => const GuestDashboardScreen());

      case departmentsList:
        return smoothRoute(settings, (_) => const DepartmentsListScreen());

      case departmentsByCategory:
        final args = settings.arguments as Map<String, dynamic>?;
        return smoothRoute(
          settings,
          (_) => DepartmentsByCategoryScreen(
            categoryKey: args?['key'] ?? 'other',
            categoryName: args?['name'] ?? 'Department',
            categoryEmoji: args?['emoji'] ?? '\u{1F3E2}',
            categoryBg: args?['bg'] as Color? ?? const Color(0xFFF8FAFC),
            categoryAsset: args?['asset'],
          ),
        );

      case departmentDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return smoothRoute(
          settings,
          (_) => DepartmentDetailScreen(department: args ?? {}),
        );

      case categorySelection:
        return smoothRoute(
          settings,
          (_) => const ChooseCategoryModernScreen(),
        );

      case submitComplaint:
        final args = settings.arguments as Map<String, dynamic>?;
        return smoothRoute(
          settings,
          (_) => SubmitComplaintScreen(
            categoryKey: args?['categoryKey'],
            categoryName: args?['categoryName'],
            isGuest: args?['isGuest'] as bool?,
          ),
        );

      case guestTrack:
        return smoothRoute(settings, (_) => const GuestTrackScreen());

      case trackComplaints:
        return smoothRoute(settings, (_) => const UserTrackScreen());

      case userTrack:
        return smoothRoute(settings, (_) => const UserTrackScreen());

      case complaintDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return smoothRoute(
          settings,
          (_) => ComplaintDetailScreen(
            complaintId: args?['complaintId'] ?? 0,
          ),
        );

      case complaintSuccess:
        final args = settings.arguments as Map<String, dynamic>?;
        return smoothRoute(
          settings,
          (_) => ComplaintSuccessScreen(
            complaintId: args?['complaintId'] ?? '',
            title: args?['title'] ?? '',
            description: args?['description'] ?? '',
          ),
        );

      case profile:
        return smoothRoute(settings, (_) => const ProfileScreen());

      case aiChat:
        return smoothRoute(settings, (_) => const AIChatScreen());

      case modernDashboard:
        return smoothRoute(settings, (_) => const ModernDashboardScreen());

      case chooseCategoryModern:
        return smoothRoute(settings, (_) => const ChooseCategoryModernScreen());

      case statsScreen:
        return smoothRoute(settings, (_) => const StatsScreen());

      case modernHome:
        return smoothRoute(settings, (_) => const ModernHomeScreen());

      default:
        return smoothRoute(
          settings,
          (context) => Scaffold(
            body: Center(
              child: Text(
                AppStrings.t(context, 'No route defined for ${settings.name}'),
              ),
            ),
          ),
        );
    }
  }
}
