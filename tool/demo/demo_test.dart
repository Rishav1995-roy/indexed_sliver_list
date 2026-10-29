@Tags(<String>['demo'])
library;

// ignore_for_file: avoid_relative_lib_imports

// Renders the example app frame by frame and writes PNGs to build/demo_frames
// and doc/. tool/make_demo.sh then turns the frames into doc/demo.gif.
//
// This is a deterministic software render of the REAL example UI (the same
// widgets and the same package code), not a device screen recording.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../example/lib/app.dart';

const Size phone = Size(390, 780);
final GlobalKey shotKey = GlobalKey();
int frameNo = 0;

Future<void> loadFonts() async {
  Future<ByteData> bytes(String f) async => ByteData.sublistView(
      Uint8List.fromList(File('tool/fonts/$f').readAsBytesSync()));
  final FontLoader roboto = FontLoader('Roboto')
    ..addFont(bytes('Roboto-Regular.ttf'))
    ..addFont(bytes('Roboto-Medium.ttf'))
    ..addFont(bytes('Roboto-Bold.ttf'));
  await roboto.load();
  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(bytes('MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> png(WidgetTester tester, String path, double ratio) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary b =
        shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await b.toImage(pixelRatio: ratio);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> frame(WidgetTester tester) async {
  final String name = (frameNo++).toString().padLeft(3, '0');
  await png(tester, 'build/demo_frames/frame_$name.png', 1.0);
}

/// Advances time by [ms] in 15 fps steps, capturing every step.
Future<void> play(WidgetTester tester, int ms) async {
  for (int t = 0; t < ms; t += 67) {
    await tester.pump(const Duration(milliseconds: 67));
    await frame(tester);
  }
}

Future<void> app(WidgetTester tester,
    {int tab = 0, Brightness? brightness}) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Real shadows instead of the solid black ones flutter_test paints.
  debugDisableShadows = false;
  await tester.pumpWidget(RepaintBoundary(
    key: shotKey,
    child:
        ExampleApp(key: UniqueKey(), initialTab: tab, brightness: brightness),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey<String>(key)));
}

void main() {
  setUpAll(() async {
    await loadFonts();
  });

  testWidgets('demo gif frames', (WidgetTester tester) async {
    Directory('build/demo_frames').createSync(recursive: true);
    for (final FileSystemEntity f
        in Directory('build/demo_frames').listSync()) {
      f.deleteSync();
    }
    await app(tester);
    await play(tester, 300);
    for (final String k in <String>['go-2500', 'go-250']) {
      await tap(tester, k);
      await play(tester, 1100);
    }
    await tap(tester, 'go-0');
    await play(tester, 1000);
    // Chat tab (reversed list).
    await tester.tap(find.text('Chat'));
    await play(tester, 300);
    await tap(tester, 'chat-middle');
    await play(tester, 1000);
    await tap(tester, 'chat-first');
    await play(tester, 1100);
    await tap(tester, 'chat-new');
    await play(tester, 400);
    await tap(tester, 'chat-latest');
    await play(tester, 700);
    debugDisableShadows = true; // flutter_test checks this before tearDown
  });

  testWidgets('screenshots', (WidgetTester tester) async {
    await app(tester);
    await tap(tester, 'go-2500');
    await tester.pumpAndSettle();
    await png(tester, 'doc/screenshot_feed_light.png', 2.0);

    await app(tester, tab: 1, brightness: Brightness.dark);
    await tap(tester, 'chat-middle');
    await tester.pumpAndSettle();
    await png(tester, 'doc/screenshot_chat_dark.png', 2.0);

    await app(tester, tab: 2);
    await png(tester, 'doc/screenshot_customize.png', 2.0);
    debugDisableShadows = true;
  });
}
