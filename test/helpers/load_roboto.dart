import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the committed Roboto font into the test environment.
///
/// Replicates the Part 0 golden-harness pattern (see
/// `test/golden/app_shell_golden_test.dart`): the font is read from disk via
/// `dart:io` rather than `rootBundle`, because flutter_test only serves
/// `flutter/assets` for files declared in pubspec and pubspec changes are out
/// of scope. Reading the same committed bytes with `File` keeps every render
/// deterministic.
Future<void> loadRoboto() async {
  final fontBytes = await File('test/fonts/Roboto-Regular.ttf').readAsBytes();
  final fontLoader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.sublistView(fontBytes)));
  await fontLoader.load();
}
