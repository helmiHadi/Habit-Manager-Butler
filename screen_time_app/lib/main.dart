import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'features/dashboard/providers/app_usage_provider.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:butler_backend_client/butler_backend_client.dart';
import 'core/routing/app_router.dart';

late final Client client;

void main() async {
  // MUST be the very first line to guarantee Flutter Engine is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Non-blocking, synchronous client initialization
  client = Client('http://10.0.2.2:8080/')
    ..connectivityMonitor = FlutterConnectivityMonitor();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found. AI agent will not work.");
  }

  final prefs = await SharedPreferences.getInstance();
  final hasCompleted = prefs.getBool('hasCompletedOnboarding') ?? false;
  final role = prefs.getString('app_role') ?? 'standalone';

  String initialRoute;
  if (!hasCompleted) {
    initialRoute = AppRouter.onboardingRoute;
  } else if (role == 'parent') {
    initialRoute = AppRouter.parentDashboardRoute;
  } else {
    initialRoute = AppRouter.dashboardRoute;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppUsageProvider(client)),
      ],
      child: ScreenTimeApp(initialRoute: initialRoute),
    ),
  );
}
