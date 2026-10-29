import 'package:flutter/widgets.dart';

import 'indexed_scroll_controller.dart';
import 'render_sliver_indexed_list.dart';

/// A lazily built sliver list whose items may have different, unknown
/// heights and that can be scrolled to any index with an
/// [IndexedScrollController].
///
/// Use it like [SliverList] inside a [CustomScrollView] (or
/// `NestedScrollView`) next to any other sliver:
///
/// ```dart
/// CustomScrollView(
///   controller: controller,
///   slivers: [
///     const SliverAppBar(pinned: true, title: Text('Feed')),
///     SliverIndexedList(
///       controller: controller,
///       itemCount: 10000,
///       itemBuilder: (context, index) => MyCard(index),
///     ),
///   ],
/// )
/// ```
///
/// Not-yet-seen items are assumed to have the average height of the items
/// measured so far (or [estimatedItemExtent] before anything was measured).
/// Scrolling and jumping stay visually stable while the estimate is refined.
class SliverIndexedList extends SliverMultiBoxAdaptorWidget {
  /// Creates a list of [itemCount] items built by [itemBuilder].
  SliverIndexedList({
    super.key,
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    this.controller,
    this.estimatedItemExtent = 100.0,
    ChildIndexGetter? findChildIndexCallback,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  })  : assert(itemCount >= 0),
        assert(estimatedItemExtent > 0),
        separated = false,
        super(
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            childCount: itemCount,
            findChildIndexCallback: findChildIndexCallback,
            addAutomaticKeepAlives: addAutomaticKeepAlives,
            addRepaintBoundaries: addRepaintBoundaries,
            addSemanticIndexes: addSemanticIndexes,
          ),
        );

  /// Like the default constructor, with a separator between items.
  ///
  /// Indices given to [IndexedScrollController] and reported by its
  /// listeners always refer to items, never to separators.
  SliverIndexedList.separated({
    super.key,
    required IndexedWidgetBuilder itemBuilder,
    required IndexedWidgetBuilder separatorBuilder,
    required int itemCount,
    this.controller,
    this.estimatedItemExtent = 100.0,
    ChildIndexGetter? findChildIndexCallback,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  })  : assert(itemCount >= 0),
        assert(estimatedItemExtent > 0),
        separated = true,
        super(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final int item = index ~/ 2;
              return index.isEven
                  ? itemBuilder(context, item)
                  : separatorBuilder(context, item);
            },
            childCount: itemCount == 0 ? 0 : itemCount * 2 - 1,
            findChildIndexCallback: findChildIndexCallback == null
                ? null
                : (Key key) {
                    final int? i = findChildIndexCallback(key);
                    return i == null ? null : i * 2;
                  },
            addAutomaticKeepAlives: addAutomaticKeepAlives,
            addRepaintBoundaries: addRepaintBoundaries,
            addSemanticIndexes: addSemanticIndexes,
            semanticIndexCallback: (Widget _, int index) =>
                index.isEven ? index ~/ 2 : null,
          ),
        );

  /// Controller used to jump to indices and to listen to visible items. It
  /// must also be the controller of the enclosing scroll view.
  final IndexedScrollController? controller;

  /// Height assumed for items that were never laid out, until the average of
  /// the measured ones takes over. A value near the real average makes the
  /// scrollbar accurate from the first frame.
  final double estimatedItemExtent;

  /// Whether a separator is built between items.
  final bool separated;

  @override
  RenderSliverIndexedList createRenderObject(BuildContext context) {
    final SliverMultiBoxAdaptorElement element =
        context as SliverMultiBoxAdaptorElement;
    return RenderSliverIndexedList(
      childManager: element,
      separated: separated,
      estimatedItemExtent: estimatedItemExtent,
      binding: controller,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSliverIndexedList renderObject) {
    renderObject
      ..separated = separated
      ..binding = controller;
  }
}
