import 'package:flutter/material.dart';
import 'package:indexed_sliver_list/indexed_sliver_list.dart';

import 'data.dart';
import 'settings.dart';

const int feedCount = 5000;

/// A CustomScrollView with an app bar, a header and a SliverIndexedList of
/// mixed-height cards. Pull to refresh and the scrollbar use the SAME
/// controller as the index jumps.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.settings, this.controller});
  final DemoSettings settings;
  final IndexedScrollController? controller;

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  late final IndexedScrollController controller =
      widget.controller ?? IndexedScrollController();
  int refreshes = 0;

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  Future<void> go(int index) {
    final DemoSettings s = widget.settings;
    return s.animate
        ? controller.animateToIndex(index,
            alignment: s.alignment, duration: const Duration(milliseconds: 900))
        : controller.jumpToIndex(index, alignment: s.alignment);
  }

  @override
  Widget build(BuildContext context) {
    final DemoSettings s = widget.settings;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: s,
      builder: (BuildContext context, _) {
        final Axis axis = s.horizontal ? Axis.horizontal : Axis.vertical;
        return Column(
          children: <Widget>[
            Expanded(
              child: RefreshIndicator(
                notificationPredicate: (n) => !s.horizontal && n.depth == 0,
                onRefresh: () async {
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                  setState(() => refreshes++);
                },
                child: Scrollbar(
                  controller: controller,
                  child: CustomScrollView(
                    controller: controller,
                    scrollDirection: axis,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: <Widget>[
                      if (!s.horizontal) ...<Widget>[
                        const SliverAppBar(
                          pinned: true,
                          title: Text('Feed'),
                        ),
                        SliverToBoxAdapter(
                            child: _Header(refreshes: refreshes)),
                      ],
                      _list(s, axis),
                      if (!s.horizontal)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('End of the feed')),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            _Controls(state: this, scheme: scheme),
          ],
        );
      },
    );
  }

  Widget _list(DemoSettings s, Axis axis) {
    Widget item(BuildContext context, int i) =>
        _PostCard(post: Post(i), axis: axis);
    return s.separators
        ? SliverIndexedList.separated(
            controller: controller,
            itemCount: feedCount,
            estimatedItemExtent: s.estimate,
            itemBuilder: item,
            separatorBuilder: (_, __) => axis == Axis.vertical
                ? const SizedBox(height: 4)
                : const SizedBox(width: 4),
          )
        : SliverIndexedList(
            controller: controller,
            itemCount: feedCount,
            estimatedItemExtent: s.estimate,
            itemBuilder: item,
          );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.refreshes});
  final int refreshes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        '$feedCount cards with different heights. Pull to refresh '
        '(refreshed $refreshes times).',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.axis});
  final Post post;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final Widget card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (post.hasImage)
            Container(
              height: post.imageHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    post.color,
                    post.color.withValues(alpha: 0.35)
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.image_outlined,
                  color: Colors.white.withValues(alpha: 0.85), size: 36),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(post.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(post.body),
              ],
            ),
          ),
        ],
      ),
    );
    return axis == Axis.horizontal
        ? SizedBox(width: 240, child: SingleChildScrollView(child: card))
        : card;
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.scheme});
  final FeedScreenState state;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final IndexedScrollController c = state.controller;
    return Material(
      elevation: 6,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ValueListenableBuilder<IndexedVisibleRange?>(
                valueListenable: c.visibleRange,
                builder: (_, IndexedVisibleRange? r, __) => Text(
                  r == null ? 'Visible: -' : 'Visible: ${r.first} .. ${r.last}',
                  key: const ValueKey<String>('visible-label'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (final int i in const <int>[0, 250, 2500, 4999])
                    FilledButton.tonal(
                      key: ValueKey<String>('go-$i'),
                      onPressed: () => state.go(i),
                      child: Text('Go to $i'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
