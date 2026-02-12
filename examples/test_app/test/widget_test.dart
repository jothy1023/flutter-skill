import 'package:flutter_test/flutter_test.dart';

import 'package:demo_app/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Visual Indicators Test'), findsOneWidget);
    expect(find.text('Button 1'), findsOneWidget);
    expect(find.text('Button 2'), findsOneWidget);
  });
}
