abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const completeProfile = '/complete-profile';
  static const accountStatus = '/account-status';
  static const home = '/home';
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
