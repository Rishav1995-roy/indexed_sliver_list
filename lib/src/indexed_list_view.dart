import 'package:flutter/widgets.dart';

import 'indexed_scroll_controller.dart';
import 'sliver_indexed_list.dart';

/// A box-model list (like [ListView]) built on [SliverIndexedList].
///
/// Supports index jumping/animation through its [controller], variable item
/// heights, separators, `reverse` (chat), horizontal scrolling and
/// `shrinkWrap`. For anything composed with other slivers use
/// [SliverIndexedList] inside a [CustomScrollView] directly.
class IndexedListView extends StatefulWidget {
  /// Creates a list of [itemCount] items.
  const IndexedListView({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.padding,
    this.physics,
    this.primary,
    this.estimatedItemExtent = 100.0,
    this.findChildIndexCallback,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
  })  : separatorBuilder = null,
        assert(itemCount >= 0);

  /// Creates a list with a separator between items.
  const IndexedListView.separated({
    super.key,
    required this.itemBuilder,
    required IndexedWidgetBuilder this.separatorBuilder,
    required this.itemCount,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.padding,
    this.physics,
    this.primary,
    this.estimatedItemExtent = 100.0,
    this.findChildIndexCallback,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
  }) : assert(itemCount >= 0);

  /// Builds item `index`.
  final IndexedWidgetBuilder itemBuilder;

  /// Builds the separator after item `index`; null for no separators.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Number of items.
  final int itemCount;

  /// Controller for index jumping; one is created internally when null.
  final IndexedScrollController? controller;

  /// Scroll axis.
  final Axis scrollDirection;

  /// Whether item 0 sits at the end (bottom) of the list, as in chats.
  final bool reverse;

  /// Whether the list takes only the space of its content. Every item is
  /// built, like any shrink-wrapped list.
  final bool shrinkWrap;

  /// Padding around the items.
  final EdgeInsetsGeometry? padding;

  /// Scroll physics.
  final ScrollPhysics? physics;

  /// See [ScrollView.primary].
  final bool? primary;

  /// Initial height guess for unmeasured items.
  final double estimatedItemExtent;

  /// Maps a key back to an index so state follows items that move.
  final ChildIndexGetter? findChildIndexCallback;

  /// See [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  /// See [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// See [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// See [ScrollView.keyboardDismissBehavior].
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// See [ScrollView.clipBehavior].
  final Clip clipBehavior;

  /// See [ScrollView.restorationId].
  final String? restorationId;

  @override
  State<IndexedListView> createState() => _IndexedListViewState();
}

class _IndexedListViewState extends State<IndexedListView> {
  IndexedScrollController? _own;

  IndexedScrollController get _controller =>
      widget.controller ?? (_own ??= IndexedScrollController());

  @override
  void didUpdateWidget(IndexedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null) {
      _own?.dispose();
      _own = null;
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IndexedScrollController controller = _controller;
    final SliverIndexedList list = widget.separatorBuilder == null
        ? SliverIndexedList(
            controller: controller,
            itemBuilder: widget.itemBuilder,
            itemCount: widget.itemCount,
            estimatedItemExtent: widget.estimatedItemExtent,
            findChildIndexCallback: widget.findChildIndexCallback,
            addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
            addRepaintBoundaries: widget.addRepaintBoundaries,
            addSemanticIndexes: widget.addSemanticIndexes,
          )
        : SliverIndexedList.separated(
            controller: controller,
            itemBuilder: widget.itemBuilder,
            separatorBuilder: widget.separatorBuilder!,
            itemCount: widget.itemCount,
            estimatedItemExtent: widget.estimatedItemExtent,
            findChildIndexCallback: widget.findChildIndexCallback,
            addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
            addRepaintBoundaries: widget.addRepaintBoundaries,
            addSemanticIndexes: widget.addSemanticIndexes,
          );
    return CustomScrollView(
      controller: controller,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      primary: widget.primary,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      clipBehavior: widget.clipBehavior,
      restorationId: widget.restorationId,
      slivers: <Widget>[
        if (widget.padding != null)
          SliverPadding(padding: widget.padding!, sliver: list)
        else
          list,
      ],
    );
  }
}
