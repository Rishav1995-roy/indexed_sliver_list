import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'item_position.dart';
import 'render_sliver_indexed_list.dart';

/// A [ScrollController] that can also scroll to an item *index*.
///
/// Pass the same instance to the scroll view (`CustomScrollView.controller`,
/// `ListView.controller`, ...) and to the `SliverIndexedList` (or
/// `IndexedListView`, which does both). Because it is a plain
/// [ScrollController], `Scrollbar`, `RefreshIndicator`, `NestedScrollView` and
/// scroll listeners keep working.
///
/// ```dart
/// final controller = IndexedScrollController();
/// await controller.animateToIndex(500, alignment: 0.5);
/// ```
class IndexedScrollController extends ScrollController
    implements IndexedListBinding {
  /// Creates a controller.
  ///
  /// When [initialIndex] is set, the list is positioned on that item (at
  /// [initialAlignment]) before the first frame is painted.
  IndexedScrollController({
    this.initialIndex,
    this.initialAlignment = 0.0,
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  }) : assert(initialAlignment >= 0 && initialAlignment <= 1);

  /// Item to show on the first frame, if any.
  final int? initialIndex;

  /// Alignment used for [initialIndex].
  final double initialAlignment;

  final List<RenderSliverIndexedList> _lists = <RenderSliverIndexedList>[];
  bool _initialPending = true;
  AnimationController? _animation;

  final ValueNotifier<List<IndexedItemPosition>> _positions =
      ValueNotifier<List<IndexedItemPosition>>(const <IndexedItemPosition>[]);
  final ValueNotifier<IndexedVisibleRange?> _range =
      ValueNotifier<IndexedVisibleRange?>(null);

  /// Every item currently intersecting the viewport, with its edges.
  ///
  /// Updated after each frame in which something changed.
  ValueListenable<List<IndexedItemPosition>> get itemPositions => _positions;

  /// First and last visible item. Only notifies when the indices change, so
  /// it is cheap to listen to while scrolling.
  ValueListenable<IndexedVisibleRange?> get visibleRange => _range;

  /// Lowest visible index, or null when nothing is visible.
  int? get firstVisibleIndex => _range.value?.first;

  /// Highest visible index, or null when nothing is visible.
  int? get lastVisibleIndex => _range.value?.last;

  /// Whether a list is currently attached.
  bool get isListAttached => _lists.isNotEmpty;

  RenderSliverIndexedList get _list {
    if (_lists.isEmpty) {
      throw StateError(
        'IndexedScrollController is not attached to a SliverIndexedList. '
        'Pass it to the list (or use IndexedListView) and call this after the first frame.',
      );
    }
    return _lists.last;
  }

  @override
  void attachList(RenderSliverIndexedList list) {
    if (!_lists.contains(list)) _lists.add(list);
    final int? index = initialIndex;
    if (_initialPending && index != null) {
      _initialPending = false;
      if (list.itemCount > index) {
        unawaited(list.jumpToItem(index, initialAlignment));
      }
    }
  }

  @override
  void detachList(RenderSliverIndexedList list) => _lists.remove(list);

  @override
  void onPositionsChanged(List<IndexedItemPosition> positions) {
    _positions.value = positions;
    if (positions.isEmpty) {
      _range.value = null;
    } else {
      _range.value =
          IndexedVisibleRange(positions.first.index, positions.last.index);
    }
  }

  /// Scrolls so that item [index] sits at [alignment] without animating.
  ///
  /// [alignment] `0.0` puts the item's leading edge at the viewport's leading
  /// edge, `0.5` centres it and `1.0` puts its trailing edge at the trailing
  /// edge. The returned future completes once the position is exact; the
  /// correction happens inside the layout pass, so no intermediate frame is
  /// painted.
  Future<void> jumpToIndex(int index, {double alignment = 0.0}) {
    assert(alignment >= 0 && alignment <= 1, 'alignment must be within 0..1');
    _stopAnimation();
    return _list.jumpToItem(index, alignment);
  }

  /// Animates so that item [index] sits at [alignment].
  ///
  /// Works for far away items whose height is not known yet: the target is
  /// re-evaluated on every frame while the animation runs and a final exact
  /// jump removes any remaining estimation error. A user drag cancels the
  /// animation. The future completes when the animation (or the cancelled
  /// remainder) is over.
  Future<void> animateToIndex(
    int index, {
    double alignment = 0.0,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    assert(alignment >= 0 && alignment <= 1, 'alignment must be within 0..1');
    final RenderSliverIndexedList list = _list;
    final ScrollPosition? position = list.scrollPosition;
    if (position == null || duration == Duration.zero) {
      return jumpToIndex(index, alignment: alignment);
    }
    _stopAnimation();
    final double start = position.pixels;
    final AnimationController animation =
        AnimationController(vsync: position.context.vsync, duration: duration);
    _animation = animation;
    bool cancelled = false;
    int ticks = 0;
    animation.addListener(() {
      if (ticks++ > 0 && position.isScrollingNotifier.value) {
        // Someone else (a drag) took over the position.
        cancelled = true;
        animation.stop();
        return;
      }
      final double target = list.targetPixels(index, alignment);
      double next = start + (target - start) * curve.transform(animation.value);
      if (position.hasContentDimensions) {
        next = next.clamp(position.minScrollExtent, position.maxScrollExtent);
      }
      position.jumpTo(next);
    });
    try {
      await animation.forward().orCancel;
    } on TickerCanceled {
      cancelled = true;
    }
    if (identical(_animation, animation)) _animation = null;
    animation.dispose();
    if (!cancelled && _lists.contains(list)) {
      await list.jumpToItem(index, alignment);
    }
  }

  /// Tells the list that [count] items were inserted before [index].
  ///
  /// Call it together with the `setState` that changes your data. The scroll
  /// position is kept on the same content when the list is scrolled away from
  /// its start (typical for chat history); at the very start the new items
  /// simply appear.
  void notifyItemsInserted(int index, {int count = 1}) {
    for (final RenderSliverIndexedList list in _lists) {
      list.notifyInserted(index, count);
    }
  }

  /// Tells the list that [count] items starting at [index] were removed.
  void notifyItemsRemoved(int index, {int count = 1}) {
    for (final RenderSliverIndexedList list in _lists) {
      list.notifyRemoved(index, count);
    }
  }

  void _stopAnimation() {
    final AnimationController? a = _animation;
    _animation = null;
    a?.stop();
  }

  @override
  void dispose() {
    _stopAnimation();
    _positions.dispose();
    _range.dispose();
    super.dispose();
  }
}
