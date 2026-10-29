import 'package:flutter_test/flutter_test.dart';
import 'package:indexed_sliver_list/indexed_sliver_list.dart';

void main() {
  test('IndexedItemPosition equality and visibility', () {
    const IndexedItemPosition a =
        IndexedItemPosition(index: 1, leadingEdge: 0.1, trailingEdge: 0.4);
    const IndexedItemPosition b =
        IndexedItemPosition(index: 1, leadingEdge: 0.1, trailingEdge: 0.4);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.isFullyVisible, isTrue);
    expect(
      const IndexedItemPosition(index: 2, leadingEdge: -0.2, trailingEdge: 0.2)
          .isFullyVisible,
      isFalse,
    );
    expect(a.toString(), contains('index: 1'));
  });

  test('IndexedVisibleRange equality', () {
    expect(const IndexedVisibleRange(1, 4), const IndexedVisibleRange(1, 4));
    expect(const IndexedVisibleRange(1, 4),
        isNot(const IndexedVisibleRange(1, 5)));
    expect(const IndexedVisibleRange(1, 4).toString(),
        '`IndexedVisibleRange(1..4)`'.replaceAll('`', ''));
  });
}
