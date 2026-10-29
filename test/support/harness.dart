import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic item height (40..129) so expected offsets can be computed.
double heightOf(int i) => 40.0 + ((i * 37) % 90);

double offsetOfItem(int i) {
  double sum = 0;
  for (int k = 0; k < i; k++) {
    sum += heightOf(k);
  }
  return sum;
}

/// Counts how many times each index was built.
class BuildLog {
  final Set<int> built = <int>{};
  int calls = 0;
}

Widget box(int i, {BuildLog? log, Axis axis = Axis.vertical}) {
  log?.built.add(i);
  log?.calls++;
  final double h = heightOf(i);
  return SizedBox(
    key: ValueKey<int>(i),
    height: axis == Axis.vertical ? h : null,
    width: axis == Axis.horizontal ? h : null,
    child: Text('Item $i'),
  );
}

Widget host(Widget child, {Size? size}) => MaterialApp(
      home: Scaffold(body: child),
    );

double topOf(WidgetTester t, int i) =>
    t.getTopLeft(find.byKey(ValueKey<int>(i))).dy;
double leftOf(WidgetTester t, int i) =>
    t.getTopLeft(find.byKey(ValueKey<int>(i))).dx;
double bottomOf(WidgetTester t, int i) =>
    t.getBottomLeft(find.byKey(ValueKey<int>(i))).dy;
