// Golden baseline test for the app shell.
//
// Determinism requirements (golden-harness spec):
//   1. Bundled Roboto font loaded into the test environment via FontLoader
//      (test/fonts/Roboto-Regular.ttf is a canonical, Apache 2.0 build).
//   2. MainApp's theme pins fontFamily: 'Roboto' so rendered text uses the
//      bundled font — never the Ahem placeholder or host-system fonts.
//   3. A committed baseline at goldens/app_shell.png; the test fails unless
//      the render matches it byte-identically.
//
// The baseline is generated with `flutter test --update-goldens` and then
// must pass without the flag on CI and locally.
//
// Note: the font is read from disk via dart:io rather than rootBundle.
// flutter_test only mocks 'flutter/assets' for files declared in pubspec
// (UNIT_TEST_ASSETS), and pubspec changes are out of scope for this slice.
// Reading the same committed bytes with File keeps the render deterministic.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/main.dart';

void main() {
  setUpAll(() async {
    final fontBytes = await File('test/fonts/Roboto-Regular.ttf').readAsBytes();
    final fontLoader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(fontBytes)));
    await fontLoader.load();
  });

  testWidgets('app shell renders identically to the golden baseline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/app_shell.png'),
    );
  });
}
