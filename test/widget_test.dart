// Widget tests for the app shell (app-shell spec RE-AS-2/RE-AS-3, design D14).
//
// MainApp requires a ProviderScope ancestor because its home — the
// configurator — reads Riverpod providers. The spec requires:
//   1. ProviderScope is an ancestor of MaterialApp.
//   2. The home is the configurator under a Scaffold with an AppBar titled
//      'Impetus' — not the Part 0 placeholder title (RE-AS-2).
//   3. No FloatingActionButton: the wallpaper spike moved to a dev-only
//      AppBar action that is one-shot (RE-AS-3).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/configurator_view.dart';
import 'package:impetus/main.dart';

void main() {
  const channel = MethodChannel('com.impetus.impetus/wallpaper');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('renders the configurator home inside a ProviderScope', (
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

    // RE-AS-2: a Scaffold with an AppBar titled 'Impetus' hosts the
    // configurator — the Part 0 placeholder home is gone.
    final appBar = find.widgetWithText(AppBar, 'Impetus');
    expect(appBar, findsOneWidget);
    expect(find.byType(ConfiguratorView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Scaffold),
        matching: find.byType(ConfiguratorView),
      ),
      findsOneWidget,
    );

    // RE-AS-3: no primary-action FAB; the spike lives in the AppBar actions.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.descendant(of: appBar, matching: find.byIcon(Icons.wallpaper)),
      findsOneWidget,
    );
  });

  testWidgets('dev spike trigger is one-shot (RE-AS-3)', (
    WidgetTester tester,
  ) async {
    // The platform reports a failed wallpaper set: mock the channel to return
    // false (an unmocked channel never completes under the fake async zone).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);

    await tester.pumpWidget(const ProviderScope(child: MainApp()));

    final trigger = find.byIcon(Icons.wallpaper);
    expect(trigger, findsOneWidget);

    await tester.tap(trigger);
    await tester.pumpAndSettle();

    // A result is shown (no mock platform channel → failure path).
    expect(find.text('Wallpaper set failed'), findsOneWidget);

    // One-shot: the trigger disables itself after the first tap, so it cannot
    // re-run the spike until the app restarts (RE-AS-3).
    final button = tester.widget<IconButton>(
      find.ancestor(of: trigger, matching: find.byType(IconButton)),
    );
    expect(button.onPressed, isNull);

    await tester.tap(trigger, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Wallpaper set failed'), findsOneWidget);
  });
}
