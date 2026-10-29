# indexed_sliver_list

[![pub version](https://img.shields.io/pub/v/indexed_sliver_list.svg)](https://pub.dev/packages/indexed_sliver_list)
[![pub points](https://img.shields.io/pub/points/indexed_sliver_list)](https://pub.dev/packages/indexed_sliver_list/score)
[![likes](https://img.shields.io/pub/likes/indexed_sliver_list)](https://pub.dev/packages/indexed_sliver_list)
[![popularity](https://img.shields.io/pub/popularity/indexed_sliver_list)](https://pub.dev/packages/indexed_sliver_list)
[![CI](https://github.com/Rishav1995-roy/indexed_sliver_list/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Rishav1995-roy/indexed_sliver_list/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-android%20%7C%20ios%20%7C%20web%20%7C%20macos%20%7C%20windows%20%7C%20linux-informational)

Jump or animate to **any index** of a lazily built list whose items have **different, unknown heights**. `SliverIndexedList` is a real sliver, so it works inside `CustomScrollView` and `NestedScrollView` next to app bars and other slivers, and its controller **is** a `ScrollController`, so `Scrollbar`, `RefreshIndicator` and scroll listeners keep working.

![Demo](https://raw.githubusercontent.com/Rishav1995-roy/indexed_sliver_list/main/doc/demo.gif)

<p>
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/indexed_sliver_list/main/doc/screenshot_feed_light.png" width="240" alt="Feed (light)">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/indexed_sliver_list/main/doc/screenshot_chat_dark.png" width="240" alt="Reversed chat (dark)">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/indexed_sliver_list/main/doc/screenshot_customize.png" width="240" alt="Customize tab">
</p>

> The GIF and screenshots are a deterministic render of the example app's real widgets (the same code the package runs on a device), produced by `tool/make_demo.sh`. They are not a screen recording of a phone.

## Why this package

`ListView` cannot scroll to an index, and `jumpTo` on a long list of variable-height items is slow because every item before the target has to be laid out ([flutter/flutter#52207](https://github.com/flutter/flutter/issues/52207)). The popular answers each leave a gap:

| | `scrollable_positioned_list` | `super_sliver_list` | `scroll_to_index` | `indexed_sliver_list` |
|---|---|---|---|---|
| Real sliver (use in `CustomScrollView` with other slivers) | No (two stacked lists; [#32](https://github.com/google/flutter.widgets/issues/32), [#140](https://github.com/google/flutter.widgets/issues/140)) | Yes | No (tags items of a normal list) | **Yes** |
| `shrinkWrap` | No ([#52](https://github.com/google/flutter.widgets/issues/52)) | Via sliver | n/a | **Yes** |
| Controller is a normal `ScrollController` | No ([#235](https://github.com/google/flutter.widgets/issues/235)) | Yes | Yes | **Yes** |
| Jump to far index, unknown heights | Yes | Yes | Slow trial scrolling | **Yes, inside one layout pass** |
| Alignment when jumping | `alignment` | `alignment` (see [#59](https://github.com/superlistapp/super_sliver_list/issues/59) with center anchors) | `preferPosition` | **0.0 to 1.0, works with pinned app bars** |
| Awaitable jump and animate | Animate only | Animate (awaitable animate requested upstream) | Yes | **Both** |
| Visible first/last index and edge fractions | `ItemPositionsListener` | Via controller | No | **`itemPositions`, `visibleRange`** |
| Reverse (chat), horizontal, separators, keep-alive | Yes | Yes | Partly | **Yes** |
| Keep place when items are inserted | No | Open request ([#71](https://github.com/superlistapp/super_sliver_list/issues/71)) | No | **`notifyItemsInserted`** |
| Maintenance | Repository archived, 258 open issues | No commit since mid-2024 ([#96](https://github.com/superlistapp/super_sliver_list/issues/96)) | Last release 2022 | New |

These are the facts at the time of writing (October 2026); `scrollable_positioned_list` and `super_sliver_list` are good packages and this one builds on the same general idea of estimating unseen items, written from scratch. If one of them already does what you need, keep using it.

### What "exact" means

The list estimates the height of items it has never built (the average of the measured ones) and keeps the content you are looking at steady while the estimate is refined. Therefore:

* `jumpToIndex(i, alignment: a)` puts item `i` **exactly** at alignment `a` (verified by the tests in `test/core_problems_test.dart`).
* `controller.offset` and the scrollbar thumb are **estimates** while far-away items are unmeasured. They become exact as items are laid out.
* `shrinkWrap: true` builds every item (like any shrink-wrapped list), so use it for short lists.

## Install

```sh
flutter pub add indexed_sliver_list
```

## Quick start

```dart
final controller = IndexedScrollController();

IndexedListView(
  controller: controller,
  itemCount: 10000,
  itemBuilder: (context, index) => MyCard(index),
);

// later
await controller.animateToIndex(5000, alignment: 0.5);
controller.jumpToIndex(42);
```

### Inside a `CustomScrollView`

Give the **same controller** to the scroll view and to the sliver:

```dart
CustomScrollView(
  controller: controller,
  slivers: [
    const SliverAppBar(pinned: true, title: Text('Feed')),
    SliverIndexedList(
      controller: controller,
      itemCount: items.length,
      itemBuilder: (context, i) => FeedCard(items[i]),
    ),
    const SliverToBoxAdapter(child: Footer()),
  ],
);
```

A pinned app bar is respected: with `alignment: 0` the item lands directly under it.

### Chat (reversed) that keeps the reader's place

```dart
IndexedListView(
  controller: controller,
  reverse: true,                 // index 0 = newest, at the bottom
  itemCount: messages.length,
  itemBuilder: (_, i) => Bubble(key: ValueKey(messages[i].id), messages[i]),
  findChildIndexCallback: (key) {          // keep widget state when indexes move
    final i = messages.indexWhere((m) => ValueKey(m.id) == key);
    return i < 0 ? null : i;
  },
);

// when a message arrives:
setState(() => messages.insert(0, newMessage));
controller.notifyItemsInserted(0);
```

If the reader scrolled up, the visible messages do not move. If she is at the bottom, the new message simply appears.

### Visible items

```dart
ValueListenableBuilder<IndexedVisibleRange?>(
  valueListenable: controller.visibleRange,   // only notifies when indexes change
  builder: (_, range, __) => Text('${range?.first} .. ${range?.last}'),
);

controller.itemPositions.addListener(() {
  for (final p in controller.itemPositions.value) {
    // p.index, p.leadingEdge, p.trailingEdge (fractions of the viewport)
  }
});
```

## API

### `IndexedScrollController` (extends `ScrollController`)

| Member | Description |
|---|---|
| `IndexedScrollController({initialIndex, initialAlignment, ...})` | `initialIndex` positions the list before the first frame |
| `Future<void> jumpToIndex(int index, {double alignment = 0})` | Jump without animation; completes when the position is exact |
| `Future<void> animateToIndex(int index, {alignment, duration, curve})` | Animate, re-targeting every frame, then an exact final jump. A user drag cancels it |
| `notifyItemsInserted(int index, {int count = 1})` / `notifyItemsRemoved(...)` | Keep measurements and the reader's place when data changes |
| `ValueListenable<List<IndexedItemPosition>> itemPositions` | Every visible item with its edges |
| `ValueListenable<IndexedVisibleRange?> visibleRange` | First and last visible index |
| `firstVisibleIndex`, `lastVisibleIndex`, `isListAttached` | Convenience getters |

`alignment`: `0.0` leading edge of the viewport (below a pinned app bar), `0.5` centred, `1.0` trailing edge.

### `SliverIndexedList` / `SliverIndexedList.separated`

| Parameter | Default | Description |
|---|---|---|
| `itemBuilder`, `itemCount` | required | Lazy item builder and the number of items |
| `separatorBuilder` | required for `.separated` | Built between items; indices given to the controller always mean items |
| `controller` | null | The `IndexedScrollController` (must also drive the scroll view) |
| `estimatedItemExtent` | 100 | Height guess for never-built items until real ones are measured |
| `findChildIndexCallback` | null | Maps a key to its index so state follows moving items |
| `addAutomaticKeepAlives`, `addRepaintBoundaries`, `addSemanticIndexes` | true | As in `SliverChildBuilderDelegate` |

### `IndexedListView` / `IndexedListView.separated`

All of the above plus `scrollDirection`, `reverse`, `shrinkWrap`, `padding`, `physics`, `primary`, `keyboardDismissBehavior`, `clipBehavior`, `restorationId`. For `cacheExtent` or other viewport options compose `SliverIndexedList` in your own `CustomScrollView`.

### `IndexedItemPosition`, `IndexedVisibleRange`, `ExtentModel`

Plain data classes. `ExtentModel` is the pure-Dart `O(log n)` offset bookkeeping (Fenwick trees), exported for testing and reuse.

## Customization (example app)

The example's *Customize* tab changes the jump alignment, animation on/off, separators, horizontal axis, `estimatedItemExtent` and the theme at runtime. Run it with `cd example && flutter run`.

## Platform support

| Android | iOS | Web | macOS | Windows | Linux |
|---|---|---|---|---|---|
| Yes | Yes | Yes | Yes | Yes | Yes |

Pure Dart and Flutter (no native code, no extra dependencies).

## Coming from `scrollable_positioned_list`

| `scrollable_positioned_list` | `indexed_sliver_list` |
|---|---|
| `ScrollablePositionedList.builder(...)` | `IndexedListView(...)` or `SliverIndexedList(...)` in a `CustomScrollView` |
| `ItemScrollController` | `IndexedScrollController` (also pass it to a `CustomScrollView` yourself; `IndexedListView` does it for you) |
| `itemScrollController.jumpTo(index: i, alignment: a)` | `controller.jumpToIndex(i, alignment: a)` |
| `await itemScrollController.scrollTo(index: i, duration: d, curve: c, alignment: a)` | `await controller.animateToIndex(i, duration: d, curve: c, alignment: a)` |
| `initialScrollIndex`, `initialAlignment` | `IndexedScrollController(initialIndex:, initialAlignment:)` |
| `ItemPositionsListener.itemPositions` (`ItemPosition.itemLeadingEdge`) | `controller.itemPositions` (`IndexedItemPosition.leadingEdge`), or `controller.visibleRange` |
| `ScrollOffsetController` / `ScrollOffsetListener` | The controller **is** a `ScrollController`: use `controller.offset`, `controller.jumpTo`, `controller.animateTo` and `addListener` |
| `scrollDirection`, `reverse`, `shrinkWrap`, `physics`, `padding`, `addSemanticIndexes` | Same names on `IndexedListView` |
| `minCacheExtent` | Use `CustomScrollView(cacheExtent: ...)` |
| `semanticChildCount`, `itemCount` | `itemCount` |
| (not possible) a list among slivers | `SliverIndexedList` |
| (not possible) `RefreshIndicator`/`Scrollbar` on the same controller | Works, pass the controller |
| (not possible) keep place on insert | `controller.notifyItemsInserted(index)` |

Differences to know about:

* Alignment is clamped to `0..1`. In a reversed list the leading edge is the bottom.
* `jumpToIndex` returns a `Future` that completes once the position is exact (it never needs more than a few frames).
* `ItemPosition` edges are fractions of the viewport in scroll direction, like before.

## FAQ

**Does it work with `NestedScrollView`?** Yes, put a `CustomScrollView` with the sliver in the `body`. This is covered by a test.

**Can I use it without the controller?** Yes, `SliverIndexedList` without a controller behaves like a `SliverList` that handles unknown heights well, but index jumping needs the controller.

**Why does `controller.offset` change by itself after a jump?** The scroll offset of far items is an estimate. When more items are measured the offset is corrected so the content under your finger does not move.

**How do I scroll to the end?** `controller.jumpToIndex(last, alignment: 1.0)`; a bare `jumpTo(maxScrollExtent)` may need a second call while the extent estimate is still refined.

**Several lists in one scroll view?** Jump calls go to the most recently attached `SliverIndexedList` of the controller; use one scroll view (and controller) per indexed list.

**Is the behaviour verified on devices?** The core behaviour is covered by widget tests on the oldest and newest supported Flutter. It has not been profiled on real devices yet; please open an issue with a reproduction if you find a case that misbehaves.

## Contributing

Issues and pull requests are welcome at https://github.com/Rishav1995-roy/indexed_sliver_list. Run `flutter analyze` and `flutter test` before opening a PR. To regenerate the demo GIF and screenshots run `tool/make_demo.sh` (needs `ffmpeg`).

## License

MIT, see [LICENSE](LICENSE).
