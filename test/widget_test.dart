// Basic Flutter widget test for the app shell.
//
// MainApp requires a ProviderScope ancestor because its home shell is a
// ConsumerWidget that reads Riverpod providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/main.dart';

void main() {
  testWidgets('renders the app title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));

    expect(find.text('Impetus'), findsOneWidget);
  });
}