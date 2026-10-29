// These tests prove the core problems of the gap:
//  1. a real sliver: CustomScrollView, shrinkWrap, a plain ScrollController
//     (scrollable_positioned_list #32, #52, #140, #235);
//  2. exact jumps to far items with unknown variable heights, without laying
//     out everything before them (flutter#52207, flutter.widgets #310);
//  3. a visible-items listener;
//  4. reverse lists (chat) that keep their place when items are inserted.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexed_sliver_list/indexed_sliver_list.dart';

import 'support/harness.dart';

void main() {
  // ---------------------------------------------------------------- problem 1
  group('1. real sliver with a normal ScrollController', () {
    testWidgets('works inside CustomScrollView next to other slivers',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(CustomScrollView(
        controller: c,
        slivers: <Widget>[
          const SliverAppBar(pinned: true, title: Text('Feed')),
          const SliverToBoxAdapter(
              child: SizedBox(height: 200, child: Text('header'))),
          SliverIndexedList(
            controller: c,
            itemCount: 2000,
            itemBuilder: (_, i) => box(i),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: 120, child: Text('footer'))),
        ],
      )));
      // Before scrolling the header and item 0 are laid out one after another.
      expect(topOf(tester, 0), kToolbarHeight + 200);
      // Jump deep into the list, with the header and a pinned app bar around.
      c.jumpToIndex(1500, alignment: 0.0);
      await tester.pump();
      expect(topOf(tester, 1500), closeTo(kToolbarHeight, 0.5));
      c.jumpToIndex(1500, alignment: 1.0);
      await tester.pump();
      expect(bottomOf(tester, 1500), closeTo(600, 0.5));
      // Back to the very first item (above is the 200px header).
      c.jumpToIndex(0);
      await tester.pump();
      expect(topOf(tester, 0), closeTo(kToolbarHeight, 0.5));
      expect(c.position.pixels, closeTo(200, 0.5));
    });

    testWidgets('the footer sliver is reachable at the real end',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(CustomScrollView(
        controller: c,
        slivers: <Widget>[
          SliverIndexedList(
              controller: c, itemCount: 60, itemBuilder: (_, i) => box(i)),
          const SliverToBoxAdapter(
              child: SizedBox(height: 120, child: Text('footer'))),
        ],
      )));
      c.jumpToIndex(59, alignment: 1.0);
      await tester.pump();
      // The user keeps scrolling to the very end.
      for (int i = 0; i < 3; i++) {
        await tester.fling(
            find.byType(CustomScrollView), const Offset(0, -600), 3000);
        await tester.pumpAndSettle();
      }
      expect(find.text('footer'), findsOneWidget);
      expect(bottomOf(tester, 59) + 120, closeTo(600, 1));
    });

    testWidgets('shrinkWrap sizes the list to its content', (tester) async {
      await tester.pumpWidget(host(SingleChildScrollView(
        child: Column(children: <Widget>[
          const Text('top'),
          IndexedListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (_, i) => box(i),
          ),
          const Text('bottom'),
        ]),
      )));
      final double expected = offsetOfItem(5);
      final double listTop =
          tester.getTopLeft(find.byKey(const ValueKey<int>(0))).dy;
      final double bottomTop = tester.getTopLeft(find.text('bottom')).dy;
      expect(bottomTop - listTop, closeTo(expected, 0.5));
    });

    testWidgets(
        'a plain ScrollController API works: listeners, jumpTo, animateTo',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      int notifications = 0;
      c.addListener(() => notifications++);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        itemCount: 500,
        itemBuilder: (_, i) => box(i),
      )));
      c.jumpTo(1000);
      await tester.pump();
      expect(c.offset, greaterThan(900)); // estimates refine, content stays put
      expect(notifications, greaterThan(0));
      final ScrollController asPlain = c;
      final Future<void> anim = asPlain.animateTo(0,
          duration: const Duration(milliseconds: 100), curve: Curves.linear);
      await tester.pumpAndSettle();
      await anim;
      expect(asPlain.offset, closeTo(0, 0.5));
    });

    testWidgets('RefreshIndicator and Scrollbar work with the list',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      int refreshed = 0;
      await tester.pumpWidget(host(RefreshIndicator(
        onRefresh: () async => refreshed++,
        child: Scrollbar(
          controller: c,
          thumbVisibility: true,
          child: IndexedListView(
            controller: c,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: 300,
            itemBuilder: (_, i) => box(i),
          ),
        ),
      )));
      await tester.fling(
          find.byType(IndexedListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(refreshed, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'works when wrapped by SliverPadding (viewport is not the parent)',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        padding: const EdgeInsets.all(8),
        itemCount: 20000,
        itemBuilder: (_, i) => box(i),
      )));
      c.jumpToIndex(9000, alignment: 0.5);
      await tester.pump();
      final double h = heightOf(9000);
      expect(topOf(tester, 9000), closeTo(0.5 * (600 - h), 0.5));
      final Future<void> anim = c.animateToIndex(15000, alignment: 0.0);
      await tester.pumpAndSettle();
      await anim;
      expect(topOf(tester, 15000), closeTo(0, 0.5));
    });

    testWidgets('works inside NestedScrollView', (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(NestedScrollView(
        headerSliverBuilder: (_, __) => const <Widget>[
          SliverAppBar(pinned: true, title: Text('Nested')),
        ],
        body: Builder(
          builder: (context) => CustomScrollView(
            controller: c,
            slivers: <Widget>[
              SliverIndexedList(
                  controller: c,
                  itemCount: 1000,
                  itemBuilder: (_, i) => box(i)),
            ],
          ),
        ),
      )));
      c.jumpToIndex(700);
      await tester.pump();
      expect(find.byKey(const ValueKey<int>(700)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------- problem 2
  group('2. exact jumps to far items of unknown height', () {
    testWidgets(
        'lands exactly for every alignment, in one frame, building few items',
        (tester) async {
      final BuildLog log = BuildLog();
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        itemCount: 100000,
        itemBuilder: (_, i) => box(i, log: log),
      )));
      for (final double a in <double>[0.0, 0.25, 0.5, 1.0]) {
        log.built.clear();
        c.jumpToIndex(60000, alignment: a);
        await tester.pump(); // ONE frame: the item must already be in place
        final double h = heightOf(60000);
        expect(topOf(tester, 60000), closeTo(a * (600 - h), 0.5),
            reason: 'alignment $a');
        // Never builds the items in between (that is the O(n) bug).
        expect(log.built.length, lessThan(60),
            reason: 'built ${log.built.length}');
      }
      // The scroll offset equals the true prefix sum (exact, not estimated).
      c.jumpToIndex(3000);
      await tester.pump();
      expect(topOf(tester, 3000), closeTo(0, 0.5));
    });

    testWidgets('jump and animate to several far indices, up and down',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        itemCount: 50000,
        itemBuilder: (_, i) => box(i),
      )));
      for (final int target in <int>[40000, 12, 25000, 49999 - 30, 5]) {
        final Future<void> f = c.animateToIndex(target, alignment: 0.5);
        await tester.pumpAndSettle();
        await f;
        final double h = heightOf(target);
        expect(topOf(tester, target), closeTo(0.5 * (600 - h), 0.5),
            reason: 'target $target');
      }
    });

    testWidgets('jumping to the last item completes (clamped at the end)',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        itemCount: 3000,
        itemBuilder: (_, i) => box(i),
      )));
      final Future<void> f = c.jumpToIndex(2999, alignment: 0.0);
      for (int i = 0; i < 20; i++) {
        await tester.pump();
      }
      await f.timeout(const Duration(seconds: 1));
      expect(bottomOf(tester, 2999), closeTo(600, 0.5));
    });

    testWidgets('initialIndex shows the item on the very first frame',
        (tester) async {
      final IndexedScrollController c =
          IndexedScrollController(initialIndex: 8000, initialAlignment: 0.5);
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        itemCount: 10000,
        itemBuilder: (_, i) => box(i),
      )));
      final double h = heightOf(8000);
      expect(topOf(tester, 8000), closeTo(0.5 * (600 - h), 0.5));
    });

    testWidgets(
        'scrolling by drag after a jump keeps content stable (no jumps)',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        itemCount: 20000,
        itemBuilder: (_, i) => box(i),
      )));
      c.jumpToIndex(10000);
      await tester.pump();
      // Drag by 100px several times: the visible item must move by the drag
      // distance (minus touch slop) - never by thousands of pixels - even
      // while the estimate is refined with every new item that scrolls in.
      for (int n = 0; n < 6; n++) {
        final int idx = c.itemPositions.value
            .firstWhere((p) => p.leadingEdge > 0.4 && p.trailingEdge < 0.9)
            .index;
        final double before = topOf(tester, idx);
        final TestGesture g = await tester.startGesture(const Offset(200, 400));
        await g.moveBy(const Offset(0, -50));
        await tester.pump();
        await g.moveBy(const Offset(0, -50));
        await tester.pump();
        await g.up();
        await tester.pump();
        final double moved = before - topOf(tester, idx);
        expect(moved, inInclusiveRange(60, 100.5),
            reason: 'step $n moved $moved');
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
  });

  // ---------------------------------------------------------------- problem 3
  group('3. visible items listener', () {
    testWidgets('reports first/last index and edge fractions', (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        itemCount: 1000,
        itemBuilder: (_, i) => box(i),
      )));
      await tester.pump();
      expect(c.firstVisibleIndex, 0);
      final List<IndexedItemPosition> p = c.itemPositions.value;
      expect(p.first.leadingEdge, closeTo(0, 1e-6));
      expect(p.first.trailingEdge, closeTo(heightOf(0) / 600, 1e-6));
      expect(p.last.index, c.lastVisibleIndex);
      // The listener reacts to a jump.
      final List<IndexedVisibleRange?> seen = <IndexedVisibleRange?>[];
      c.visibleRange.addListener(() => seen.add(c.visibleRange.value));
      c.jumpToIndex(500, alignment: 0.5);
      await tester.pump();
      await tester.pump();
      expect(c.firstVisibleIndex, lessThanOrEqualTo(500));
      expect(c.lastVisibleIndex, greaterThanOrEqualTo(500));
      expect(seen, isNotEmpty);
      final IndexedItemPosition target =
          c.itemPositions.value.firstWhere((e) => e.index == 500);
      final double h = heightOf(500);
      expect(target.leadingEdge, closeTo(0.5 * (600 - h) / 600, 1e-3));
      expect(target.isFullyVisible, isTrue);
    });
  });

  // ---------------------------------------------------------------- problem 4
  group('4. reverse lists (chat)', () {
    testWidgets('reverse puts item 0 at the bottom and jumps work',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        reverse: true,
        itemCount: 5000,
        itemBuilder: (_, i) => box(i),
      )));
      expect(bottomOf(tester, 0), closeTo(600, 0.5));
      c.jumpToIndex(3000, alignment: 0.0); // leading edge = bottom
      await tester.pump();
      expect(bottomOf(tester, 3000), closeTo(600, 0.5));
      c.jumpToIndex(3000, alignment: 1.0);
      await tester.pump();
      expect(topOf(tester, 3000), closeTo(0, 0.5));
    });

    testWidgets('inserting new messages keeps the reader in place',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      // Messages are identified by id; id k has height heightOf(k).
      List<int> ids =
          List<int>.generate(400, (i) => 399 - i); // index 0 = newest
      late StateSetter set;
      await tester
          .pumpWidget(host(StatefulBuilder(builder: (context, setState) {
        set = setState;
        return IndexedListView(
          controller: c,
          reverse: true,
          itemCount: ids.length,
          itemBuilder: (_, i) => SizedBox(
            key: ValueKey<int>(ids[i]),
            height: heightOf(ids[i]),
            child: Text('m${ids[i]}'),
          ),
          findChildIndexCallback: (key) {
            final int id = (key as ValueKey<int>).value;
            final int i = ids.indexOf(id);
            return i < 0 ? null : i;
          },
        );
      })));
      // Reader scrolled up to message 350.
      c.jumpToIndex(ids.indexOf(350), alignment: 0.5);
      await tester.pump();
      final double before = topOf(tester, 350);
      // Three new messages arrive.
      set(() => ids = <int>[1003, 1002, 1001, ...ids]);
      c.notifyItemsInserted(0, count: 3);
      await tester.pump();
      await tester.pump();
      expect(topOf(tester, 350), closeTo(before, 0.5));

      // A reader at the bottom just sees the new message.
      c.jumpTo(0);
      await tester.pump();
      set(() => ids = <int>[1004, ...ids]);
      c.notifyItemsInserted(0);
      await tester.pump();
      expect(find.byKey(const ValueKey<int>(1004)), findsOneWidget);
      expect(bottomOf(tester, 1004), closeTo(600, 0.5));
    });
  });

  // ---------------------------------------------------------------- extras
  group('other behaviour', () {
    testWidgets('horizontal axis', (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        scrollDirection: Axis.horizontal,
        itemCount: 4000,
        itemBuilder: (_, i) => box(i, axis: Axis.horizontal),
      )));
      c.jumpToIndex(2500, alignment: 0.5);
      await tester.pump();
      final double w = heightOf(2500);
      expect(leftOf(tester, 2500), closeTo(0.5 * (800 - w), 0.5));
    });

    testWidgets('separators count in layout but not in indices',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView.separated(
        controller: c,
        itemCount: 1000,
        itemBuilder: (_, i) => box(i),
        separatorBuilder: (_, i) =>
            const SizedBox(height: 10, child: Divider()),
      )));
      c.jumpToIndex(700, alignment: 0.0);
      await tester.pump();
      expect(topOf(tester, 700), closeTo(0, 0.5));
      expect(c.firstVisibleIndex, 700);
      c.jumpToIndex(10, alignment: 0.0);
      await tester.pump();
      expect(topOf(tester, 10), closeTo(0, 0.5));
      // exact: sum of 10 items + 10 separators
      expect(c.position.pixels, closeTo(offsetOfItem(10) + 100, 0.5));
    });

    testWidgets('keep-alive state survives scrolling away', (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(IndexedListView(
        controller: c,
        itemCount: 300,
        itemBuilder: (_, i) =>
            i == 2 ? _Keeper(key: const ValueKey<int>(2)) : box(i),
      )));
      await tester.tap(find.byKey(const ValueKey<int>(2)));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);
      c.jumpToIndex(250);
      await tester.pump();
      expect(find.byKey(const ValueKey<int>(2)), findsNothing);
      c.jumpToIndex(0);
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);
    });

    testWidgets('empty list and shrinking lists do not throw', (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      int count = 100;
      late StateSetter set;
      await tester.pumpWidget(host(StatefulBuilder(builder: (context, s) {
        set = s;
        return IndexedListView(
            controller: c, itemCount: count, itemBuilder: (_, i) => box(i));
      })));
      c.jumpToIndex(90);
      await tester.pump();
      set(() => count = 3);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey<int>(2)), findsOneWidget);
      set(() => count = 0);
      await tester.pump();
      expect(c.itemPositions.value, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller throws a helpful error when not attached',
        (tester) async {
      final IndexedScrollController c = IndexedScrollController();
      addTearDown(c.dispose);
      expect(() => c.jumpToIndex(1), throwsStateError);
    });
  });
}

class _Keeper extends StatefulWidget {
  const _Keeper({super.key});
  @override
  State<_Keeper> createState() => _KeeperState();
}

class _KeeperState extends State<_Keeper> with AutomaticKeepAliveClientMixin {
  int n = 0;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => n++),
      child: SizedBox(height: 60, child: Text('count $n')),
    );
  }
}
