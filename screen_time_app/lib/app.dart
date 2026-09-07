import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';

class ScreenTimeApp extends StatelessWidget {
  final String initialRoute;
  const ScreenTimeApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Time Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Forcing dark mode as requested
      themeMode: ThemeMode.dark,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
