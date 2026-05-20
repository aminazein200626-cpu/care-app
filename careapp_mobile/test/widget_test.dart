// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:careapp_mobile/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CareApp());  // ✅ غير MyApp إلى CareApp

    // Verify that welcome screen is shown
    expect(find.text('CareApp'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });
}