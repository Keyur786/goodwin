import 'package:flutter_test/flutter_test.dart';
import 'package:goodwin/main.dart';

void main() {
  testWidgets('demo app boots and shows Goodwin splash screen', (tester) async {
    await tester.pumpWidget(const GoodwinDemoApp());

    // App starts with Goodwin branded splash screen
    expect(find.text('GOODWIN'), findsOneWidget);
    expect(find.text('WHOLESALE MARKET'), findsOneWidget);
  });
}
