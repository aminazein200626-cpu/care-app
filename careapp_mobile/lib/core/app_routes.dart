// lib/core/app_routes.dart
class AppRoutes {
  // ==================== AUTH SCREENS ====================
  static const String welcome = '/';
  static const String login = '/login';
  static const String registerRole = '/register-role';
  static const String registerClient = '/register-client';
  static const String registerProvider = '/register-provider';
  
  // ==================== CLIENT SCREENS ====================
  static const String clientDashboard = '/client/dashboard';
  static const String clientProfile = '/client/profile';
  static const String clientDependents = '/client/dependents';
  static const String clientAuthorized = '/client/authorized';
  static const String clientSearch = '/client/search';
  static const String clientBooking = '/client/booking';
  static const String clientTracking = '/client/tracking';
  static const String clientPayments = '/client/payments';
  static const String clientFeedback = '/client/feedback';
  static const String clientNotifications = '/client/notifications';
  static const String clientHistory = '/client/history';
  static const String clientChat = '/client/chat';
  
  // ✅ Client Additional Screens
  static const String settingsScreen = '/client/settings';
  static const String changePasswordScreen = '/client/change-password';
  static const String adsScreen = '/client/ads';
  static const String callHistory = '/call-history';
  static const String helpCenter = '/help';
  
  // ✅ NEW Client Booking Flow Screens
  static const String selectDependant = '/client/select-dependant';
  static const String availabilityScreen = '/client/availability';
  static const String addTasksBeforeBooking = '/client/add-tasks-before-booking';
  
  // ✅ Aliases (أسماء مختصرة لسهولة الاستخدام في الكود)
  static const String homeScreen = clientDashboard;
  static const String profileScreen = clientProfile;
  static const String bookingsScreen = clientBooking;
  static const String searchScreen = clientSearch;
  static const String serviceHistoryScreen = clientHistory;
  static const String notificationsScreen = clientNotifications;
  static const String dependantsScreen = clientDependents;
  static const String authorizedPersonsScreen = clientAuthorized;
  static const String feedbackScreen = clientFeedback;
  static const String paymentScreen = clientPayments;
  static const String trackingScreen = clientTracking;
  static const String chatScreen = clientChat;
  
  // ==================== PROVIDER SCREENS ====================
  static const String providerDashboard = '/provider/dashboard';
  static const String providerProfile = '/provider/profile';
  static const String providerCalendar = '/provider/calendar';
  static const String providerRequests = '/provider/requests';
  static const String providerTracking = '/provider/tracking';
  static const String providerPayments = '/provider/payments';
  static const String providerAds = '/provider/ads';
  static const String providerCommunication = '/provider/communication';
  static const String providerFeedback = '/provider/feedback';
  static const String providerHistory = '/provider/history';
  static const String providerSettings = '/provider/settings';
  static const String providerChangePassword = '/provider/change-password';
  static const String providerEditProfile = '/provider/edit-profile';
  static const String providerNotifications = '/provider/notifications';
  
  // ✅ NEW Provider Screens
  static const String providerBookingRequests = '/provider/booking-requests';
  
  // ✅ Aliases للمستخدم السريع
  static const String providerHome = providerDashboard;
  
  // ==================== AUTHORIZED PERSON SCREENS ====================
  static const String authorizedDashboard = '/authorized/dashboard';
  static const String authorizedTracking = '/authorized/tracking';
  static const String authorizedProfile = '/authorized/profile';
  static const String authorizedChat = '/authorized/chat';
  static const String authorizedNotifications = '/authorized/notifications';
  
  // ✅ Aliases
  static const String authorizedHome = authorizedDashboard;
}