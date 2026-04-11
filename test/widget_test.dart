import 'package:flutter_test/flutter_test.dart';
import 'package:lifetravel_mobile/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const LifeTravelApp());
    expect(find.text('LifeTravel Chat'), findsOneWidget);
  });
}
