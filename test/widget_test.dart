import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/main.dart';

void main() {
  testWidgets('the app boots to the dev menu', (tester) async {
    await tester.pumpWidget(const HogPocketApp());
    expect(find.text('Hog Pocket'), findsOneWidget);
    expect(find.text('Sprite gallery'), findsOneWidget);
  });
}
