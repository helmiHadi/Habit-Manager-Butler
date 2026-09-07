
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:screen_time_app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<String>(create: (_) => 'Placeholder Provider'),
        ],
        child: const ScreenTimeApp(initialRoute: '/'),
      ),
    );

    // Verify that our app bar title is present.
    expect(find.text('Screen Time'), findsOneWidget);
  });
}
