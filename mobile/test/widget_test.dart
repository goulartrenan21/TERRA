import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terra/main.dart';

void main() {
  testWidgets('TerraApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TerraApp()));
    // Smoke test — app boots without throwing
    expect(tester.takeException(), isNull);
  });
}
