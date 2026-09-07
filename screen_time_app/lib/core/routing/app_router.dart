import 'package:flutter/material.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/parent_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/onboarding_screen.dart';

class AppRouter {
  static const String dashboardRoute = '/';
  static const String parentDashboardRoute = '/parent_dashboard';
  static const String onboardingRoute = '/onboarding';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dashboardRoute:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case parentDashboardRoute:
        return MaterialPageRoute(builder: (_) => const ParentDashboardScreen());
      case onboardingRoute:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
