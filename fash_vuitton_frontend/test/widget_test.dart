import 'package:flutter_test/flutter_test.dart';
import 'package:fash_vuitton_frontend/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DressupBuddyApp());
    expect(find.byType(DressupBuddyApp), findsOneWidget);
  });
}
