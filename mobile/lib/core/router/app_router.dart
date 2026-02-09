import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:educonnect/features/auth/presentation/pages/login_page.dart';
import 'package:educonnect/features/auth/presentation/pages/register_page.dart';
import 'package:educonnect/features/auth/presentation/pages/role_selection_page.dart';
import 'package:educonnect/features/home/presentation/pages/shell_page.dart';
import 'package:educonnect/features/splash/presentation/pages/splash_page.dart';

/// Converts a [Stream] into a [ChangeNotifier] so GoRouter re-evaluates
/// its redirect whenever the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter createRouter(AuthBloc authBloc) => GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: true,
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isAuthRoute = state.matchedLocation.startsWith('/auth');
        final isSplash = state.matchedLocation == '/splash';

        if (isSplash) return null;

        if (authState is AuthUnauthenticated && !isAuthRoute) {
          return '/auth/login';
        }

        if (authState is AuthAuthenticated && isAuthRoute) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
        GoRoute(path: '/auth/login', builder: (_, __) => const LoginPage()),
        GoRoute(
          path: '/auth/register',
          builder: (_, __) => const RoleSelectionPage(),
        ),
        GoRoute(
          path: '/auth/register/:role',
          builder: (_, state) =>
              RegisterPage(role: state.pathParameters['role'] ?? 'student'),
        ),
        GoRoute(path: '/home', builder: (_, __) => const ShellPage()),
      ],
    );
