// Widget tests for the app shell (app-shell spec).
//
// MainApp requires a ProviderScope ancestor because its home shell is a
// ConsumerWidget that reads Riverpod providers. The spec requires:
//   1. ProviderScope is an ancestor of MaterialApp.
//   2. The home screen shows the identifiable placeholder ('Impetus').
//   3. A FloatingActionButton spike trigger exists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/main.dart';

void main() {
  testWidgets('renders the app shell inside a ProviderScope', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));

    // Spec: ProviderScope wraps MaterialApp.
    final materialApp = find.byType(MaterialApp);
    expect(materialApp, findsOneWidget);
    expect(
      find.ancestor(of: materialApp, matching: find.byType(ProviderScope)),
      findsOneWidget,
    );

    // Spec: placeholder home screen shows the app title.
    expect(find.text('Impetus'), findsOneWidget);

    // Spec: one-shot spike trigger FAB with wallpaper icon.
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    expect(
      find.descendant(of: fab, matching: find.byIcon(Icons.wallpaper)),
      findsOneWidget,
    );
  });
}
