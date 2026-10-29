import 'package:flutter_test/flutter_test.dart';
import 'package:indexed_sliver_list/indexed_sliver_list.dart';

void main() {
  test('unknown items use the initial estimate, then the mean', () {
    final ExtentModel m = ExtentModel(initialEstimate: 100, length: 10);
    expect(m.total, 1000);
    expect(m.offsetOf(4), 400);
    m.setExtent(0, 50);
    m.setExtent(1, 150);
    expect(m.estimate, 100);
    m.setExtent(2, 40);
    expect(m.estimate, closeTo(80, 1e-9));
    expect(m.offsetOf(3), 240);
    expect(m.offsetOf(5), closeTo(240 + 2 * 80, 1e-9));
    expect(m.total, closeTo(240 + 7 * 80, 1e-9));
  });

  test('indexAt is the inverse of offsetOf', () {
    final ExtentModel m = ExtentModel(initialEstimate: 60, length: 500);
    for (int i = 0; i < 500; i += 3) {
      m.setExtent(i, 30.0 + (i % 11) * 7);
    }
    for (int i = 0; i < 500; i += 7) {
      expect(m.indexAt(m.offsetOf(i) + 0.001), i);
    }
    expect(m.indexAt(-5), 0);
    expect(m.indexAt(1e9), 499);
  });

  test('insert/remove keep measurements attached to items', () {
    final ExtentModel m = ExtentModel(initialEstimate: 10, length: 3);
    m.setExtent(0, 20);
    m.setExtent(1, 30);
    m.setExtent(2, 40);
    m.insert(0, 2);
    expect(m.length, 5);
    expect(m.isKnown(0), isFalse);
    expect(m.extentOf(2), 20);
    expect(m.extentOf(4), 40);
    m.remove(2, 1);
    expect(m.length, 4);
    expect(m.extentOf(2), 30);
    m.resize(2);
    expect(m.length, 2);
    m.clear();
    expect(m.knownCount, 0);
  });

  test('remeasuring changes the sum', () {
    final ExtentModel m = ExtentModel(initialEstimate: 10, length: 2);
    m.setExtent(0, 20);
    expect(m.setExtent(0, 20), isFalse);
    expect(m.setExtent(0, 25), isTrue);
    expect(m.offsetOf(1), 25);
  });
}
