import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/run/screens/run_active_screen.dart';
import '../../features/run/screens/capture_screen.dart';
import '../../features/run/screens/run_summary_screen.dart';
import '../../features/feed/screens/feed_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/ranking_screen.dart';
import '../../features/profile/screens/user_profile_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthed = session != null;
      final loc = state.matchedLocation;

      final isPublicRoute = loc == '/splash' ||
          loc == '/login' ||
          loc.startsWith('/onboarding');

      if (!isAuthed && !isPublicRoute) return '/login';
      if (isAuthed && (loc == '/login' || loc == '/splash')) return '/app/map';
      return null;
    },
    refreshListenable: GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange,
    ),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Authenticated shell (bottom nav) ───────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/app/map',
            builder: (_, __) => const MapScreen(),
            routes: [
              GoRoute(
                path: 'run/active',
                pageBuilder: (_, __) => const NoTransitionPage(child: RunActiveScreen()),
              ),
              GoRoute(
                path: 'run/capture',
                pageBuilder: (_, __) => const NoTransitionPage(child: CaptureScreen()),
              ),
            ],
          ),
          GoRoute(
            path: '/app/feed',
            builder: (_, __) => const FeedScreen(),
          ),
          GoRoute(
            path: '/app/profile',
            builder: (_, __) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'ranking',
                builder: (_, __) => const RankingScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/app/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),

      // ── Routes over shell (push) ────────────────────────────────────────────
      GoRoute(
        path: '/run/summary/:id',
        builder: (_, state) => RunSummaryScreen(activityId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/user/:id',
        builder: (_, state) => UserProfileScreen(userId: state.pathParameters['id']!),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Página não encontrada: ${state.error}')),
    ),
  );
});

// Adapts Supabase stream to Listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}
