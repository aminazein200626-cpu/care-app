import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/theme_provider.dart';
import 'core/app_theme.dart';
import 'core/app_routes.dart';

// Auth Screens
import 'presentation/auth/welcome_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/register_role_screen.dart';
import 'presentation/auth/register_client_screen.dart';
import 'presentation/auth/register_provider_screen.dart';

// Client Screens
import 'presentation/client/professional_dashboard.dart';
import 'presentation/client/profile_screen.dart';
import 'presentation/client/dependants_screen.dart';
import 'presentation/client/authorized_persons_screen.dart';
import 'presentation/client/search_screen.dart';
import 'presentation/client/bookings_screen.dart';
import 'presentation/client/tracking_screen.dart';
import 'presentation/client/payment_screen.dart';
import 'presentation/client/feedback_screen.dart';
import 'presentation/client/notifications_screen.dart';
import 'presentation/client/chat_screen.dart' as client_chat;
import 'presentation/client/settings_screen.dart';
import 'presentation/client/ads_screen.dart';
import 'presentation/client/call_history_screen.dart';
import 'presentation/client/service_history_screen.dart';
import 'presentation/client/help_center_screen.dart';
import 'presentation/client/change_password_screen.dart';

// NEW Client Screens
import 'presentation/client/select_dependant_screen.dart';
import 'presentation/client/availability_screen.dart';
import 'presentation/client/add_tasks_before_booking_screen.dart';

// Provider Screens
import 'presentation/provider/provider_dashboard.dart';
import 'presentation/provider/profile_page.dart';
import 'presentation/provider/calendar_page.dart';
import 'presentation/provider/consult_requests_screen.dart';
import 'presentation/provider/tracking_screen.dart' as provider_tracking;
import 'presentation/provider/payment_page.dart';
import 'presentation/provider/ads_management_page.dart';
import 'presentation/provider/communication_screen.dart' as provider_communication;
import 'presentation/provider/feedback_rating_page.dart';
import 'presentation/provider/service_history_page.dart';
import 'presentation/provider/settings_page.dart';
import 'presentation/provider/notifications_page.dart';
import 'presentation/provider/change_password_page.dart';
import 'presentation/provider/edit_profile_page.dart';

// NEW Provider Screens
import 'presentation/provider/booking_requests_screen.dart';

// Authorized Screens
import 'presentation/authorized/authorized_dashboard.dart';
import 'presentation/authorized/authorized_tracking_screen.dart';
import 'presentation/authorized/authorized_profile_screen.dart';
import 'presentation/authorized/authorized_chat_screen.dart' as authorized_chat;
import 'presentation/authorized/authorized_notifications_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CareApp());
}

class CareApp extends StatelessWidget {
  const CareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<AuthService, ThemeProvider>(
        builder: (context, authService, themeProvider, child) {
          return MaterialApp(
            title: 'CareApp',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            initialRoute: authService.isAuthenticated
                ? _getInitialRoute(authService.currentUser?.role)
                : AppRoutes.welcome,
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  String _getInitialRoute(String? role) {
    switch (role) {
      case 'Client':
        return AppRoutes.clientDashboard;
      case 'Provider':
        return AppRoutes.providerDashboard;
      case 'AuthorizedPerson':
        return AppRoutes.authorizedDashboard;
      default:
        return AppRoutes.welcome;
    }
  }

  Route? _onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      // ==================== AUTH ====================
      case AppRoutes.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.registerRole:
        return MaterialPageRoute(builder: (_) => const RegisterRoleScreen());
      case AppRoutes.registerClient:
        return MaterialPageRoute(builder: (_) => const RegisterClientScreen());
      case AppRoutes.registerProvider:
        return MaterialPageRoute(builder: (_) => const RegisterProviderScreen());

      // ==================== CLIENT SCREENS ====================
      case AppRoutes.clientDashboard:
        return MaterialPageRoute(builder: (_) => const ProfessionalDashboard());
      case AppRoutes.clientProfile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case AppRoutes.clientDependents:
        return MaterialPageRoute(builder: (_) => const DependantsScreen());
      case AppRoutes.clientAuthorized:
        return MaterialPageRoute(builder: (_) => const AuthorizedPersonsScreen());
      case AppRoutes.clientSearch:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case AppRoutes.clientBooking:
        return MaterialPageRoute(builder: (_) => const BookingsScreen());
      case AppRoutes.clientTracking:
        if (args != null && args is Map && args.containsKey('bookingId')) {
          return MaterialPageRoute(
            builder: (_) => TrackingScreen(bookingId: args['bookingId']),
          );
        }
        return MaterialPageRoute(builder: (_) => const TrackingScreen(bookingId: ''));
      case AppRoutes.paymentScreen:
        return MaterialPageRoute(builder: (_) => const PaymentScreen());
      case AppRoutes.clientFeedback:
        return MaterialPageRoute(builder: (_) => const FeedbackScreen());
      case AppRoutes.clientNotifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case AppRoutes.clientHistory:
        return MaterialPageRoute(builder: (_) => const ServiceHistoryScreen());
      case AppRoutes.clientChat:
        if (args != null && args is Map) {
          return MaterialPageRoute(
            builder: (_) => client_chat.ChatScreen(
              providerId: args['providerId']?.toString() ?? '',
              providerName: args['providerName']?.toString() ?? 'Provider',
              providerAvatar: args['providerAvatar']?.toString(),
              bookingId: args['bookingId']?.toString(),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const client_chat.ChatScreen(
            providerId: '',
            providerName: 'Provider',
          ),
        );
      case AppRoutes.settingsScreen:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.adsScreen:
        return MaterialPageRoute(builder: (_) => const AdsScreen());
      case AppRoutes.changePasswordScreen:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      case '/call-history':
        return MaterialPageRoute(builder: (_) => const CallHistoryScreen());
      case '/help':
        return MaterialPageRoute(builder: (_) => const HelpCenterScreen());

      // ==================== NEW CLIENT SCREENS ====================
      case '/client/select-dependant':
        if (args != null && args is Map) {
          return MaterialPageRoute(
            builder: (_) => SelectDependantScreen(
              providerId: args['providerId'] as String? ?? '',
              providerName: args['providerName'] as String? ?? '',
              serviceName: args['serviceName'] as String? ?? '',
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const SizedBox.shrink());

      case '/client/availability':
        if (args != null && args is Map) {
          return MaterialPageRoute(
            builder: (_) => AvailabilityScreen(
              providerId: args['providerId'] as String? ?? '',
              providerName: args['providerName'] as String? ?? '',
              serviceName: args['serviceName'] as String? ?? '',
              dependantId: args['dependantId'] as String? ?? '',
              dependantName: args['dependantName'] as String? ?? '',
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const SizedBox.shrink());

      case '/client/add-tasks-before-booking':
        if (args != null && args is Map) {
          Map<String, dynamic> selectedSlot = {};
          if (args['selectedSlot'] is Map) {
            selectedSlot = Map<String, dynamic>.from(args['selectedSlot']);
          } else if (args['selectedSlot'] is String) {
            // إذا كانت القيمة نصاً، يمكن تحويلها إلى خريطة فارغة
            selectedSlot = {};
          }
          return MaterialPageRoute(
            builder: (_) => AddTasksBeforeBookingScreen(
              providerId: args['providerId'] as String? ?? '',
              providerName: args['providerName'] as String? ?? '',
              serviceName: args['serviceName'] as String? ?? '',
              dependantId: args['dependantId'] as String? ?? '',
              dependantName: args['dependantName'] as String? ?? '',
              selectedDate: args['selectedDate'] as String? ?? '',
              selectedSlot: selectedSlot,
              location: args['location'] as String? ?? '',
              notes: args['notes'] as String? ?? '',
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const SizedBox.shrink());

      // ==================== PROVIDER SCREENS ====================
      case AppRoutes.providerDashboard:
        return MaterialPageRoute(builder: (_) => const ProviderDashboard(providerName: "Provider"));
      case AppRoutes.providerProfile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case AppRoutes.providerCalendar:
        return MaterialPageRoute(builder: (_) => const CalendarPage());
      case AppRoutes.providerRequests:
        return MaterialPageRoute(builder: (_) => const ConsultRequestsScreen());
      case AppRoutes.providerTracking:
        return MaterialPageRoute(builder: (_) => const provider_tracking.TrackingScreen());
      case AppRoutes.providerPayments:
        return MaterialPageRoute(builder: (_) => const PaymentPage());
      case AppRoutes.providerAds:
        return MaterialPageRoute(builder: (_) => const AdsManagementPage());
      case AppRoutes.providerCommunication:
        return MaterialPageRoute(builder: (_) => const provider_communication.CommunicationScreen());
      case AppRoutes.providerFeedback:
        return MaterialPageRoute(builder: (_) => const FeedbackRatingPage());
      case AppRoutes.providerHistory:
        return MaterialPageRoute(builder: (_) => const ServiceHistoryPage());
      case AppRoutes.providerSettings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      case AppRoutes.providerNotifications:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());
      case AppRoutes.providerChangePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordPage());
      case AppRoutes.providerEditProfile:
        return MaterialPageRoute(builder: (_) => const EditProfilePage());

      // ==================== NEW PROVIDER SCREENS ====================
      case AppRoutes.providerBookingRequests:
        return MaterialPageRoute(builder: (_) => const BookingRequestsScreen());

      // ==================== AUTHORIZED SCREENS ====================
      case AppRoutes.authorizedDashboard:
        return MaterialPageRoute(builder: (_) => const AuthorizedDashboard());
      case AppRoutes.authorizedTracking:
        if (args != null && args is Map) {
          return MaterialPageRoute(
            builder: (_) => AuthorizedTrackingScreen(
              serviceId: args['serviceId']?.toString() ?? '',
              serviceName: args['serviceName']?.toString() ?? '',
              providerName: args['providerName']?.toString() ?? '',
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const AuthorizedTrackingScreen(
            serviceId: '',
            serviceName: '',
            providerName: '',
          ),
        );
      case AppRoutes.authorizedProfile:
        return MaterialPageRoute(builder: (_) => const AuthorizedProfileScreen());
      case AppRoutes.authorizedChat:
        if (args != null && args is Map) {
          return MaterialPageRoute(
            builder: (_) => authorized_chat.AuthorizedChatScreen(
              serviceId: args['serviceId']?.toString() ?? '',
              providerName: args['providerName']?.toString() ?? '',
              providerId: args['providerId']?.toString() ?? '',
              providerAvatar: args['providerAvatar']?.toString(),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const authorized_chat.AuthorizedChatScreen(
            serviceId: '',
            providerName: '',
            providerId: '',
          ),
        );
      case AppRoutes.authorizedNotifications:
        return MaterialPageRoute(builder: (_) => const AuthorizedNotificationsScreen());

      // ==================== DEFAULT ====================
      default:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
    }
  }
}