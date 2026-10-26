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
}
