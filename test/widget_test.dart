// Basic smoke test: verifies the NexMusic app widget can be constructed
// and mounted without throwing during the initial frame.

import 'package:flutter_test/flutter_test.dart';

import 'package:nexmusic/main.dart';

void main() {
  testWidgets('NexMusic app builds without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NexMusic());
    await tester.pump();

    // If we got this far without an exception, the widget tree mounted.
    expect(tester.takeException(), isNull);
  });
}
