// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/app.dart';

void main() {
  testWidgets('example app: feed jump, chat tab and customize tab work',
      (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.byKey(const ValueKey<String>('go-2500')));
    await tester.pumpAndSettle();
    expect(find.text('Card #2500'), findsWidgets);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('chat-new')));
    await tester.pumpAndSettle();
    expect(find.textContaining('#2000'), findsOneWidget);
    await tester.tap(find.text('Customize'));
    await tester.pumpAndSettle();
    expect(find.text('Horizontal feed'), findsOneWidget);
    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
