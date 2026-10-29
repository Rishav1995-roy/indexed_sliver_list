## 0.0.1

* Initial release.
* `SliverIndexedList` (and `.separated`): a real multi-box sliver for lazily built items of different, unknown heights.
* `IndexedListView`: box wrapper with `reverse`, `shrinkWrap`, horizontal axis, padding and separators.
* `IndexedScrollController`: a `ScrollController` with `jumpToIndex`, `animateToIndex` (both awaitable, alignment `0.0` to `1.0`), `initialIndex`, `notifyItemsInserted` / `notifyItemsRemoved` and visible-item listeners (`itemPositions`, `visibleRange`).
* `ExtentModel`: pure Dart `O(log n)` extent bookkeeping (public for testing and reuse).
