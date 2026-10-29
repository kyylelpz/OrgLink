import '../features/admin/presentation/screens/admin_screen.dart';
import '../features/admin/presentation/viewmodels/admin_view_model.dart';
import '../core/widgets/authenticated_shell.dart';
import '../features/attendance/presentation/attendance_scope.dart';
import '../features/attendance/presentation/screens/attendance_screens.dart';
import '../features/attendance/presentation/screens/qr_screens.dart';
import '../features/events/presentation/event_scope.dart';
import '../features/events/presentation/screens/event_discovery_screen.dart';
import '../features/events/presentation/screens/my_events_screen.dart';
import '../features/events/presentation/screens/event_details_screen.dart';
import '../features/events/presentation/screens/event_editor_screen.dart';
import '../features/events/presentation/screens/event_management_screen.dart';
import '../features/organizations/presentation/organization_scope.dart';
import '../features/organizations/presentation/screens/organization_discovery_screen.dart';
import '../features/organizations/presentation/screens/organization_details_screen.dart';
import '../features/organizations/presentation/screens/my_organizations_screen.dart';
import '../features/memberships/presentation/screens/member_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_routes.dart';
import '../core/widgets/placeholder_screen.dart';
import '../features/auth/presentation/screens/auth_screens.dart';
import '../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/coming_soon_screen.dart';
import '../features/attendance/presentation/scanner_route_observer.dart';
import '../features/profile/presentation/screens/complete_profile_screen.dart';

GoRouter createAppRouter(AuthViewModel auth) => GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: auth,
  redirect: (_, state) => authRedirect(
    auth.status,
    state.uri.path,
    profileStatus: auth.profileStatus,
    eligible: auth.profile?.isEligible == true,
    requiresEmailVerification: auth.user?.requiresEmailVerification == true,
  ),
  routes: [
    GoRoute(
      path: AppRoutes.admin,
      builder: (_, _) => const AdminScreen(section: AdminSection.dashboard),
    ),
    GoRoute(
      path: AppRoutes.adminAccounts,
      builder: (_, _) => const AdminScreen(section: AdminSection.accounts),
    ),
    GoRoute(
      path: AppRoutes.adminOrganizations,
      builder: (_, _) => const AdminScreen(section: AdminSection.organizations),
    ),
    GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, _) => const OnboardingScreen(),
    ),
    GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
    GoRoute(path: AppRoutes.signUp, builder: (_, _) => const SignUpScreen()),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (_, _) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.verifyEmail,
      builder: (_, _) => const EmailVerificationScreen(),
    ),
    GoRoute(
      path: AppRoutes.linkPassword,
      builder: (_, _) => const LinkPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.resetEmailSent,
      builder: (_, _) => const ResetEmailSentScreen(),
    ),
    GoRoute(
      path: AppRoutes.resetPassword,
      builder: (_, state) =>
          ResetPasswordScreen(code: state.uri.queryParameters['oobCode'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.resetSuccess,
      builder: (_, _) => auth.passwordResetSucceeded
          ? const PasswordResetSuccessScreen()
          : const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.emailAction,
      builder: (_, state) => state.uri.queryParameters['mode'] == 'verifyEmail'
          ? EmailActionScreen(code: state.uri.queryParameters['oobCode'] ?? '')
          : state.uri.queryParameters['mode'] == 'resetPassword'
          ? ResetPasswordScreen(
              code: state.uri.queryParameters['oobCode'] ?? '',
            )
          : const InvalidEmailActionScreen(),
    ),
    ShellRoute(
      builder: (_, state, child) => auth.profile?.isEligible == true
          ? AuthenticatedShell(
              key: ValueKey(auth.user?.id),
              path: state.uri.path,
              child: child,
            )
          : child,
      routes: [
        GoRoute(
          path: AppRoutes.completeProfile,
          builder: (_, _) => const CompleteProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.accountStatus,
          builder: (_, _) => const AccountStatusScreen(),
        ),
        GoRoute(
          path: AppRoutes.calendar,
          builder: (_, _) => const ComingSoonScreen(
            title: 'Calendar',
            message:
                'The event calendar is coming soon. Browse current events from Home.',
            icon: Icons.calendar_month_outlined,
          ),
        ),
        GoRoute(
          path: AppRoutes.notifications,
          builder: (_, _) => const ComingSoonScreen(
            title: 'Notifications',
            message:
                'Notifications are coming soon. No notification feed is available yet.',
            icon: Icons.notifications_outlined,
          ),
        ),
        ShellRoute(
          builder: (_, _, child) => OrganizationScope(child: child),
          routes: [
            ShellRoute(
              observers: [scannerRouteObserver],
              builder: (_, _, child) => EventHubScope(child: child),
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (_, _) => const HomeScreen(),
                ),
                GoRoute(
                  path: AppRoutes.qr,
                  builder: (_, _) => const QRLandingScreen(),
                ),
                GoRoute(
                  path: AppRoutes.qrActions,
                  builder: (_, _) => const QRHubScreen(),
                ),
                GoRoute(
                  path: AppRoutes.qrScan,
                  builder: (_, _) => const ScannerScreen(),
                ),
                GoRoute(
                  path: AppRoutes.myQRCode,
                  builder: (_, _) =>
                      const MyAttendanceScope(child: MyQRCodeScreen()),
                ),
                GoRoute(
                  path: AppRoutes.myAttendance,
                  builder: (_, _) =>
                      const MyAttendanceScope(child: MyAttendanceScreen()),
                ),
                GoRoute(
                  path: AppRoutes.attendanceHub,
                  builder: (_, _) => const AttendanceSelectionScreen(),
                ),
                GoRoute(
                  path: '/organizations/:organizationId/attendance',
                  builder: (_, state) => AttendanceSelectionScreen(
                    initialOrganization: state.pathParameters['organizationId'],
                  ),
                ),
                GoRoute(
                  path: AppRoutes.events,
                  builder: (_, _) => const EventDiscoveryScreen(),
                ),
                GoRoute(
                  path: AppRoutes.myEvents,
                  builder: (_, _) => const MyEventsScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/organizations/:organizationId/events/:eventId/attendance',
              builder: (_, state) => EventContextScope(
                organizationId: state.pathParameters['organizationId']!,
                eventId: state.pathParameters['eventId']!,
                child: const AttendanceScope(
                  child: AttendanceScreen(report: false),
                ),
              ),
            ),
            GoRoute(
              path:
                  '/organizations/:organizationId/events/:eventId/attendance/report',
              builder: (_, state) => EventContextScope(
                organizationId: state.pathParameters['organizationId']!,
                eventId: state.pathParameters['eventId']!,
                child: const AttendanceScope(
                  child: AttendanceScreen(report: true),
                ),
              ),
            ),
            GoRoute(
              path: '/organizations/:organizationId/events/manage',
              builder: (_, state) => EventContextScope(
                organizationId: state.pathParameters['organizationId']!,
                child: const EventManagementScreen(),
              ),
            ),
            _createEventRoute(auth),
            GoRoute(
              path: '/organizations/:organizationId/events/:eventId',
              builder: (_, state) => EventContextScope(
                organizationId: state.pathParameters['organizationId']!,
                eventId: state.pathParameters['eventId']!,
                child: const EventDetailsScreen(),
              ),
            ),
            GoRoute(
              path: '/organizations/:organizationId/events/:eventId/edit',
              builder: (_, state) => EventContextScope(
                organizationId: state.pathParameters['organizationId']!,
                eventId: state.pathParameters['eventId']!,
                child: const EventEditorScreen(),
              ),
            ),
            GoRoute(
              path:
                  '/organizations/:organizationId/events/:eventId/participants',
              builder: (_, state) => EventContextScope(
                organizationId: state.pathParameters['organizationId']!,
                eventId: state.pathParameters['eventId']!,
                child: const ParticipantsScreen(),
              ),
            ),
            GoRoute(
              path:
                  '/organizations/:organizationId/events/:eventId/registration',
              builder: (_, state) => EventContextScope(
                organizationId: state.pathParameters['organizationId']!,
                eventId: state.pathParameters['eventId']!,
                child: const RegistrationConfirmationScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.organizations,
              builder: (_, _) => const OrganizationDiscoveryScreen(),
            ),
            GoRoute(
              path: AppRoutes.myOrganizations,
              builder: (_, _) => const MyOrganizationsScreen(),
            ),
            GoRoute(
              path: AppRoutes.membershipRequests,
              builder: (_, _) =>
                  const MyOrganizationsScreen(requestsOnly: true),
            ),
            GoRoute(
              path: '/organizations/:organizationId',
              builder: (_, state) => OrganizationDetailsScope(
                id: state.pathParameters['organizationId']!,
                child: const OrganizationDetailsScreen(),
              ),
            ),
            GoRoute(
              path: '/organizations/:organizationId/requests',
              builder: (_, state) => OrganizationDetailsScope(
                id: state.pathParameters['organizationId']!,
                child: const MemberListScreen(pending: true),
              ),
            ),
            GoRoute(
              path: '/organizations/:organizationId/members',
              builder: (_, state) => OrganizationDetailsScope(
                id: state.pathParameters['organizationId']!,
                child: const MemberListScreen(pending: false),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, _) => PlaceholderScreen(
    title: 'Page Unavailable',
    message: 'This page could not be found.',
    action: FilledButton(
      onPressed: () => context.go(AppRoutes.splash),
      child: const Text('Return to OrgLink'),
    ),
  ),
);

// Route-level exit handling also covers shell tabs and AppBackButton navigation.
GoRoute _createEventRoute(AuthViewModel auth) {
  final editorKey = GlobalKey<EventEditorScreenState>();
  return GoRoute(
    path: '/organizations/:organizationId/events/new',
    builder: (_, state) => EventContextScope(
      organizationId: state.pathParameters['organizationId']!,
      child: EventEditorScreen(key: editorKey),
    ),
    onExit: (_, _) {
      final editor = editorKey.currentState;
      // Never hold up a forced sign-out, account switch or eligibility redirect.
      if (editor == null ||
          auth.user?.id != editor.ownerUid ||
          auth.profile?.isEligible != true) {
        return true;
      }
      return editor.confirmExit();
    },
  );
}

String? authRedirect(
  AuthStatus status,
  String path, {
  ProfileStatus profileStatus = ProfileStatus.loading,
  bool eligible = false,
  bool requiresEmailVerification = false,
}) {
  // Action codes are bearer credentials validated by Firebase, never a dashboard bypass.
  if ([
    AppRoutes.resetPassword,
    AppRoutes.emailAction,
    AppRoutes.resetSuccess,
    AppRoutes.resetEmailSent,
  ].contains(path)) {
    return null;
  }
  if (status == AuthStatus.loading || status == AuthStatus.error) {
    return path == AppRoutes.splash ? null : AppRoutes.splash;
  }
  if (status == AuthStatus.signedOut) {
    return path == AppRoutes.signIn ||
            path == AppRoutes.onboarding ||
            path == AppRoutes.signUp ||
            path == AppRoutes.forgotPassword
        ? null
        : AppRoutes.signIn;
  }
  if (requiresEmailVerification) {
    return path == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
  }
  if (profileStatus == ProfileStatus.loading ||
      profileStatus == ProfileStatus.error) {
    return path == AppRoutes.splash ? null : AppRoutes.splash;
  }
  if (profileStatus == ProfileStatus.incomplete) {
    return path == AppRoutes.completeProfile ? null : AppRoutes.completeProfile;
  }
  if (!eligible) {
    return path == AppRoutes.accountStatus || path == AppRoutes.completeProfile
        ? null
        : AppRoutes.accountStatus;
  }
  if (path == AppRoutes.admin || path.startsWith('${AppRoutes.admin}/')) {
    return null;
  }
  if (path == AppRoutes.qr ||
      path.startsWith('${AppRoutes.qr}/') ||
      path == AppRoutes.myAttendance ||
      path == AppRoutes.attendanceHub ||
      path == AppRoutes.completeProfile ||
      path == AppRoutes.home ||
      path == AppRoutes.linkPassword ||
      path == AppRoutes.calendar ||
      path == AppRoutes.notifications ||
      path == AppRoutes.events ||
      path == AppRoutes.myEvents ||
      path == AppRoutes.organizations ||
      path == AppRoutes.myOrganizations ||
      path == AppRoutes.membershipRequests ||
      path.startsWith('${AppRoutes.organizations}/')) {
    return null;
  }
  return AppRoutes.home;
}
