import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/main.dart';
import 'package:impetus/services/wallpaper_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.impetus.impetus/wallpaper');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MainApp)));

  testWidgets('app shell renders placeholder and spike FAB', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));

    expect(find.text('Impetus'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('tapping the spike FAB sends the test PNG and reports success',
      (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });

    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    expect(containerOf(tester).read(spikeStateProvider), 0,
        reason: 'spike starts idle');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'setBitmap');
    expect(calls.single.arguments, orderedEquals(kSpikePngBytes));
    expect(containerOf(tester).read(spikeStateProvider), 2,
        reason: 'spike transitions to success');
    expect(find.text('Wallpaper set successfully'), findsOneWidget);
  });

  testWidgets('spike shows loading state while the platform call is pending',
      (tester) async {
    final gate = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => gate.future);

    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(containerOf(tester).read(spikeStateProvider), 1,
        reason: 'spike shows loading while pending');

    gate.complete(true);
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(spikeStateProvider), 2,
        reason: 'spike reaches success after the platform call completes');
  });

  testWidgets('spike reports error state and SnackBar when platform fails',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'SET_BITMAP_FAILED',
        message: 'WallpaperManager threw',
      );
    });

    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(spikeStateProvider), 3,
        reason: 'spike transitions to error');
    expect(find.textContaining('Spike failed'), findsOneWidget);
    expect(find.textContaining('SET_BITMAP_FAILED'), findsOneWidget);
  });

  testWidgets('spike trigger is one-shot: second tap does not re-invoke',
      (tester) async {
    var callCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      callCount++;
      return true;
    });

    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(callCount, 1, reason: 'one-shot trigger must not re-invoke');
  });
}