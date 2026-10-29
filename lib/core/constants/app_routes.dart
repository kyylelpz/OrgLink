abstract final class AppRoutes {
  static const admin = '/admin',
      adminAccounts = '/admin/accounts',
      adminOrganizations = '/admin/organizations';
  static const qr = '/qr',
      myQRCode = '/qr/my-code',
      qrScan = '/qr/scan',
      myAttendance = '/my-attendance',
      attendanceHub = '/attendance';
  static String attendanceManagement(String org) =>
      '${organization(org)}/attendance';
  static String attendance(String org, String eventId) =>
      '${event(org, eventId)}/attendance';
  static String attendanceReport(String org, String eventId) =>
      '${attendance(org, eventId)}/report';
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const linkPassword = '/link-password';
  static const resetEmailSent = '/reset-email-sent';
  static const resetPassword = '/reset-password';
  static const resetSuccess = '/password-reset-success';
  static const emailAction = '/__/auth/action';
  static const completeProfile = '/complete-profile';
  static const accountStatus = '/account-status';
  static const home = '/home';
  static const calendar = '/calendar';
  static const notifications = '/notifications';
  static const qrActions = '/qr/actions';
  static const organizations = '/organizations';
  static const myOrganizations = '/my-organizations';
  static const membershipRequests = '/membership-requests';
  static String organization(String id) =>
      '$organizations/${Uri.encodeComponent(id)}';
  static String manageMembers(String id) => '${organization(id)}/requests';
  static String memberRoster(String id) => '${organization(id)}/members';
  static const events = '/events';
  static const myEvents = '/my-events';
  static String manageEvents(String org) =>
      '${organization(org)}/events/manage';
  static String createEvent(String org) => '${organization(org)}/events/new';
  static String event(String org, String id) =>
      '${organization(org)}/events/${Uri.encodeComponent(id)}';
  static String editEvent(String org, String id) => '${event(org, id)}/edit';
  static String participants(String org, String id) =>
      '${event(org, id)}/participants';
  static String confirmRegistration(String org, String id) =>
      '${event(org, id)}/registration';
}
