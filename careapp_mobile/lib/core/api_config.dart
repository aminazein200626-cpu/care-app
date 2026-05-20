class ApiConfig {
 static const String baseUrl = 'http://192.168.1.10:5001';
  
  // Auth
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String registerProvider = '/api/auth/register-provider';
  static const String changePassword = '/api/auth/change-password';
  
  // Client
  static const String clientProfile = '/api/client/profile';
  static const String clientDependents = '/api/client/dependents';
  static const String clientAuthorized = '/api/client/authorized';
  static const String clientBookings = '/api/client/bookings';
  static const String clientProviders = '/api/client/providers';
  static const String clientTracking = '/api/client/tracking';
  static const String clientPayments = '/api/client/payments';
  static const String clientFeedback = '/api/client/feedback';
  static const String clientNotifications = '/api/client/notifications';
  static const String clientAds = '/api/client/ads';
  
  // Provider
  static const String providerProfile = '/api/provider/profile';
  static const String providerStats = '/api/provider/stats';
  static const String providerBookings = '/api/provider/bookings';
  static const String providerAvailability = '/api/provider/availability';
  static const String providerTracking = '/api/provider/tracking';
  static const String providerEarnings = '/api/provider/earnings';
  static const String providerPayments = '/api/provider/payments';
  static const String providerWithdraw = '/api/provider/withdraw';
  static const String providerAds = '/api/provider/ads';
  static const String providerNotifications = '/api/provider/notifications';
  static const String providerReviews = '/api/provider/reviews';
  
  // Authorized
  static const String authorizedClients = '/api/authorized/clients';
  static const String authorizedTracking = '/api/authorized/tracking';
  
  // Public
  static const String publicCategories = '/api/public/categories';
  static const String publicServices = '/api/public/services';
}