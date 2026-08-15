import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/services/wallpaper_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.impetus.impetus/wallpaper');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('WallpaperBridge.setBitmap', () {
    test(
      'invokes setBitmap with the PNG bytes on the wallpaper channel',
      () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return true;
            });

        final result = await WallpaperBridge.setBitmap(kSpikePngBytes);

        expect(result, isTrue);
        expect(calls, hasLength(1));
        expect(calls.single.method, 'setBitmap');
        expect(calls.single.arguments, orderedEquals(kSpikePngBytes));
      },
    );

    test('returns false when the platform returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);

      expect(await WallpaperBridge.setBitmap(kSpikePngBytes), isFalse);
    });

    test('returns false when the platform returns false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => false);

      expect(await WallpaperBridge.setBitmap(kSpikePngBytes), isFalse);
    });

    test('propagates PlatformException with code INVALID_ARGUMENT', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: 'INVALID_ARGUMENT',
              message: 'PNG bytes must not be null',
            );
          });

      await expectLater(
        WallpaperBridge.setBitmap(kSpikePngBytes),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'INVALID_ARGUMENT')
              .having(
                (e) => e.message,
                'message',
                'PNG bytes must not be null',
              ),
        ),
      );
    });

    test('propagates PlatformException with code INVALID_BITMAP', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: 'INVALID_BITMAP',
              message: 'Failed to decode bitmap from provided bytes',
            );
          });

      await expectLater(
        WallpaperBridge.setBitmap(kSpikePngBytes),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'INVALID_BITMAP')
              .having(
                (e) => e.message,
                'message',
                'Failed to decode bitmap from provided bytes',
              ),
        ),
      );
    });

    test('propagates PlatformException with code SET_BITMAP_FAILED', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: 'SET_BITMAP_FAILED',
              message: 'WallpaperManager threw',
            );
          });

      await expectLater(
        WallpaperBridge.setBitmap(kSpikePngBytes),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'SET_BITMAP_FAILED')
              .having((e) => e.message, 'message', 'WallpaperManager threw'),
        ),
      );
    });
  });
}
