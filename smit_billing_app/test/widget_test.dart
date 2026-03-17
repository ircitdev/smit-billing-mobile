import 'package:flutter_test/flutter_test.dart';
import 'package:smit_billing/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const SmitBillingApp());
  });
}
