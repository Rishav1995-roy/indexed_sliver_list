import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show ScrollPosition;

import 'extent_model.dart';
import 'item_position.dart';

/// Receives events from a [RenderSliverIndexedList]. Implemented by the
/// controller; kept as an interface so the render object stays decoupled.
abstract interface class IndexedListBinding {
  /// Called when the render object is attached to the render tree.
  void attachList(RenderSliverIndexedList list);

  /// Called when the render object leaves the render tree.
  void detachList(RenderSliverIndexedList list);

  /// Called (after the frame) when the visible items changed.
  void onPositionsChanged(List<IndexedItemPosition> positions);
}

class _JumpRequest {
  _JumpRequest(this.rawIndex, this.alignment);
  final int rawIndex;
  final double alignment;
  final Completer<void> completer = Completer<void>();
  int frames = 0;
}

class _ModelOp {
  const _ModelOp(this.start, this.count, this.insert);
  final int start;
  final int count;
  final bool insert;
}

/// Render object behind `SliverIndexedList`.
///
/// It is a regular multi-box sliver (so it composes with every other sliver),
/// but instead of walking the list from index 0 it asks an [ExtentModel] which
/// item covers the current scroll offset and lays out from there. Unknown
/// items are estimated; whenever the estimate changes the scroll offset is
/// corrected so the content the user looks at does not move.
class RenderSliverIndexedList extends RenderSliverMultiBoxAdaptor {
  /// Creates the render object.
  RenderSliverIndexedList({
    required super.childManager,
    required bool separated,
    required double estimatedItemExtent,
    IndexedListBinding? binding,
  })  : _separated = separated,
        _binding = binding,
        model = ExtentModel(initialEstimate: estimatedItemExtent);

  /// The extent bookkeeping (exposed for tests).
  final ExtentModel model;

  bool _separated;
  IndexedListBinding? _binding;

  /// Whether odd child indices are separators.
  set separated(bool value) {
    if (_separated == value) return;
    _separated = value;
    model.clear();
    markNeedsLayout();
  }

  /// The object notified about visible items.
  IndexedListBinding? get binding => _binding;
  set binding(IndexedListBinding? value) {
    if (_binding == value) return;
    if (attached) _binding?.detachList(this);
    _binding = value;
    if (attached) _binding?.attachList(this);
  }

  _JumpRequest? _jump;
  final List<_ModelOp> _ops = <_ModelOp>[];
  int _cycles = 0;
  bool _postFrameScheduled = false;
  bool _rangeCheckPending = false;
  List<IndexedItemPosition> _positions = const <IndexedItemPosition>[];
  List<IndexedItemPosition>? _pendingPositions;

  // Last known layout facts, used to compute jump targets outside layout.
  double _preceding = 0;
  double _overlap = 0;
  double _viewportExtent = 0;

  static const int _maxCyclesPerFrame = 8;
  static const int _maxJumpFrames = 12;

  int _raw(int item) => _separated ? item * 2 : item;

  /// The scroll position of the enclosing viewport, if it has one.
  ScrollPosition? get _offset {
    // The viewport is not necessarily the parent (SliverPadding, SliverSafeArea,
    // SliverMainAxisGroup, ... can sit in between).
    final RenderAbstractViewport? v = RenderAbstractViewport.maybeOf(this);
    if (v is RenderViewportBase && v.offset is ScrollPosition) {
      return v.offset as ScrollPosition;
    }
    return null;
  }

  /// The scroll position driving this sliver (null for custom offsets).
  ScrollPosition? get scrollPosition => _offset;

  /// Number of items (without separators).
  int get itemCount {
    final int raw = childManager.childCount;
    return _separated ? (raw + 1) ~/ 2 : raw;
  }

  /// Currently visible items.
  List<IndexedItemPosition> get positions => _positions;

  /// Pixels the viewport must be scrolled to so that [item] sits at
  /// [alignment], based on the current estimates.
  double targetPixels(int item, double alignment) {
    final int raw = _raw(item);
    final double extent = model.extentOf(raw);
    final double visible = _viewportExtent - _overlap;
    final double inSliver =
        model.offsetOf(raw) - _overlap - alignment * (visible - extent);
    return math.max(0, _preceding + inSliver);
  }

  /// Whether the extent of [item] has been measured.
  bool isItemMeasured(int item) => model.isKnown(_raw(item));

  /// Scrolls so that [item] sits at [alignment] (0 = leading edge of the
  /// viewport, 1 = trailing edge). The future completes when the position is
  /// exact (or the end of the scrollable was reached).
  Future<void> jumpToItem(int item, double alignment) {
    assert(item >= 0 && item < itemCount, 'index $item out of range');
    _jump?.completer.complete();
    final _JumpRequest request =
        _JumpRequest(_raw(item), alignment.clamp(0.0, 1.0));
    _jump = request;
    _rangeCheckPending = true;
    _cycles = 0;
    markNeedsLayout();
    _schedulePostFrame();
    return request.completer.future;
  }

  /// Tells the model that [count] items were inserted before [item] so the
  /// measurements stay attached to the right items.
  void notifyInserted(int item, int count) {
    final int oldRaw = childManager.childCount;
    final int start = math.min(_raw(item), oldRaw);
    _ops.add(_ModelOp(start, _separated ? count * 2 : count, true));
    markNeedsLayout();
  }

  /// Tells the model that [count] items starting at [item] were removed.
  void notifyRemoved(int item, int count) {
    final int oldRaw = childManager.childCount;
    final int oldItems = itemCount;
    int start = _raw(item);
    if (_separated && item + count >= oldItems && item > 0) start -= 1;
    _ops.add(_ModelOp(start, _separated ? count * 2 : count, false));
    assert(oldRaw >= 0);
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _binding?.attachList(this);
  }

  @override
  void detach() {
    _binding?.detachList(this);
    _jump?.completer.complete();
    _jump = null;
    super.detach();
  }

  void _schedulePostFrame() {
    if (_postFrameScheduled || !attached) return;
    _postFrameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _postFrameScheduled = false;
      _cycles = 0;
      if (!attached) return;
      final List<IndexedItemPosition>? pending = _pendingPositions;
      if (pending != null) {
        _pendingPositions = null;
        _positions = pending;
        _binding?.onPositionsChanged(pending);
      }
      if (_rangeCheckPending) {
        // Flutter leaves out-of-range pixels alone when the extent estimate
        // shrinks, so a jump to the end must make sure it did not overshoot.
        final ScrollPosition? off = _offset;
        if (off != null && off.hasContentDimensions) {
          if (off.pixels > off.maxScrollExtent + 0.5) {
            off.correctBy(off.maxScrollExtent - off.pixels);
            markNeedsLayout();
            _schedulePostFrame();
            return;
          }
          if (_jump == null) _rangeCheckPending = false;
        }
      }
      final _JumpRequest? jump = _jump;
      if (jump != null) {
        jump.frames++;
        final ScrollPosition? off = _offset;
        final bool clamped =
            off != null && off.hasContentDimensions && _isClamped(off, jump);
        if (clamped || jump.frames > _maxJumpFrames) {
          _finishJump();
        } else {
          markNeedsLayout();
          _schedulePostFrame();
        }
      }
    });
  }

  bool _isClamped(ScrollPosition off, _JumpRequest jump) {
    final double wanted = _desiredPixels(jump);
    final double pixels = off.pixels;
    final bool atEnd =
        wanted > pixels + 0.5 && pixels >= off.maxScrollExtent - 0.5;
    final bool atStart =
        wanted < pixels - 0.5 && pixels <= off.minScrollExtent + 0.5;
    return atEnd || atStart;
  }

  void _finishJump() {
    final _JumpRequest? jump = _jump;
    _jump = null;
    jump?.completer.complete();
  }

  double _desiredPixels(_JumpRequest jump, {bool clamp = false}) {
    final double extent = model.extentOf(jump.rawIndex);
    final double visible = _viewportExtent - _overlap;
    final double inSliver = model.offsetOf(jump.rawIndex) -
        _overlap -
        jump.alignment * (visible - extent);
    double wanted = math.max(0, _preceding + inSliver);
    final ScrollPosition? off = _offset;
    if (clamp && off != null && off.hasContentDimensions) {
      // Never ask for more than the scrollable can reach (the end of the
      // list): otherwise the viewport's clamp and this correction would fight.
      wanted =
          math.max(off.minScrollExtent, math.min(wanted, off.maxScrollExtent));
    }
    return wanted;
  }

  void _collectAll() {
    if (childCount > 0) collectGarbage(childCount, 0);
  }

  double _extentOfChild(RenderBox child) => paintExtentOf(child);

  void _setOffsets() {
    RenderBox? child = firstChild;
    while (child != null) {
      final SliverMultiBoxAdaptorParentData pd =
          child.parentData! as SliverMultiBoxAdaptorParentData;
      pd.layoutOffset = model.offsetOf(indexOf(child));
      child = childAfter(child);
    }
  }

  @override
  void performLayout() {
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final int rawCount = childManager.childCount;
    _preceding = constraints.precedingScrollExtent;
    // The overlap is only meaningful once the sliver reaches the top of the
    // viewport; before that remember the last meaningful value.
    if (constraints.scrollOffset > precisionErrorTolerance) {
      _overlap = constraints.overlap;
    }
    _viewportExtent = constraints.viewportMainAxisExtent;
    final double scrollOffset = constraints.scrollOffset;
    final ScrollPosition? off = _offset;

    // ---- anchor: the item at the current offset, kept still across changes.
    model.resize(model.length); // no-op, keeps asserts simple
    int anchor = model.indexAt(scrollOffset);
    final double anchorDelta =
        model.length == 0 ? 0 : scrollOffset - model.offsetOf(anchor);
    final bool anchorOps = scrollOffset > precisionErrorTolerance;
    for (final _ModelOp op in _ops) {
      if (op.insert) {
        if (model.length > 0 && op.start <= anchor && anchorOps) {
          anchor += op.count;
        }
        model.insert(math.min(op.start, model.length), op.count);
      } else {
        if (anchor >= op.start + op.count) {
          anchor -= op.count;
        } else if (anchor >= op.start) {
          anchor = op.start;
        }
        model.remove(op.start, op.count);
      }
    }
    _ops.clear();
    model.resize(rawCount);
    if (rawCount > 0) anchor = anchor.clamp(0, rawCount - 1);

    if (rawCount == 0) {
      _collectAll();
      geometry = SliverGeometry.zero;
      childManager.didFinishLayout();
      _publish(const <IndexedItemPosition>[]);
      _finishJump();
      return;
    }

    // ---- jump session: cheap early correction when far from the target.
    final _JumpRequest? jump = _jump;
    if (jump != null && off != null && jump.rawIndex < rawCount) {
      if (_cycles < _maxCyclesPerFrame) {
        final double delta = _desiredPixels(jump, clamp: true) - off.pixels;
        if (delta.abs() > math.max(constraints.viewportMainAxisExtent, 1) &&
            !model.isKnown(jump.rawIndex)) {
          _cycles++;
          _schedulePostFrame();
          geometry = SliverGeometry(scrollOffsetCorrection: delta);
          return;
        }
      }
    }

    final BoxConstraints childConstraints = constraints.asBoxConstraints();
    final double cacheStart =
        math.max(0.0, scrollOffset + constraints.cacheOrigin);
    final double targetEnd = cacheStart + constraints.remainingCacheExtent;
    final int startIndex = model.indexAt(cacheStart);

    // ---- make sure we have a sensible first child.
    if (firstChild != null) {
      final int firstIdx = indexOf(firstChild!);
      final int lastIdx = indexOf(lastChild!);
      if (lastIdx < startIndex ||
          firstIdx > startIndex + 30 ||
          lastIdx >= rawCount) {
        _collectAll();
      }
    }
    if (firstChild == null) {
      if (!addInitialChild(
          index: startIndex, layoutOffset: model.offsetOf(startIndex))) {
        geometry = SliverGeometry(
            scrollExtent: model.total, maxPaintExtent: model.total);
        childManager.didFinishLayout();
        return;
      }
    }

    // Layout of this pass happens in the coordinates of the model as it is
    // NOW. Measuring children changes the estimate (and with it every offset
    // of the global model), so the window of children is built relative to
    // the first child, and the difference is handed to the viewport as one
    // scroll correction afterwards.
    double localFirst = model.offsetOf(indexOf(firstChild!));
    double localEnd = localFirst;

    // ---- measure everything already built.
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      model.setExtent(indexOf(child), _extentOfChild(child));
      localEnd += _extentOfChild(child);
      child = childAfter(child);
    }

    // Returns true when a scroll correction was handed to the viewport.
    bool correct() {
      if (_cycles >= _maxCyclesPerFrame) return false;
      double? correction;
      if (jump != null && off != null && jump.rawIndex < rawCount) {
        final double delta = _desiredPixels(jump, clamp: true) - off.pixels;
        if (delta.abs() > 0.5) correction = delta;
      } else if (jump == null) {
        final double now = model.offsetOf(anchor) + anchorDelta;
        correction = math.max(now - scrollOffset, -scrollOffset);
        if (correction.abs() <= precisionErrorTolerance) correction = null;
      }
      if (correction == null) return false;
      _cycles++;
      _schedulePostFrame();
      _setOffsets();
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return true;
    }

    // Measuring the first children may have changed the estimate: settle the
    // scroll offset BEFORE deciding how many children are needed, otherwise a
    // shifted estimate could ask for a huge number of leading children.
    if (correct()) return;

    // ---- fill upwards (bounded: a correction handles anything larger).
    int leadingAdded = 0;
    while (indexOf(firstChild!) > 0 &&
        leadingAdded < 400 &&
        localFirst > cacheStart + precisionErrorTolerance) {
      final RenderBox? added =
          insertAndLayoutLeadingChild(childConstraints, parentUsesSize: true);
      if (added == null) break;
      leadingAdded++;
      model.setExtent(indexOf(added), _extentOfChild(added));
      localFirst -= _extentOfChild(added);
    }

    // ---- fill downwards.
    while (indexOf(lastChild!) < rawCount - 1 &&
        localEnd < targetEnd - precisionErrorTolerance) {
      final RenderBox? added = insertAndLayoutChild(
        childConstraints,
        after: lastChild!,
        parentUsesSize: true,
      );
      if (added == null) break;
      model.setExtent(indexOf(added), _extentOfChild(added));
      localEnd += _extentOfChild(added);
    }

    // The new children may have refined the estimate once more.
    if (correct()) return;

    if (jump != null && model.isKnown(jump.rawIndex)) {
      final double delta = off == null ? 0 : _desiredPixels(jump) - off.pixels;
      if (delta.abs() <= 0.5) _finishJump();
    }

    _setOffsets();

    // ---- garbage collection (children entirely outside the cache window).
    // (skipped while the cycle budget is exhausted: the window may then be
    // slightly off and the next frame settles it)
    if (_cycles < _maxCyclesPerFrame) {
      int leading = 0;
      int trailing = 0;
      for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
        final int i = indexOf(c);
        if (model.offsetOf(i + 1) <= cacheStart - precisionErrorTolerance) {
          leading++;
        } else {
          break;
        }
      }
      for (RenderBox? c = lastChild; c != null; c = childBefore(c)) {
        final int i = indexOf(c);
        if (model.offsetOf(i) >= targetEnd + precisionErrorTolerance &&
            leading + trailing < childCount - 1) {
          trailing++;
        } else {
          break;
        }
      }
      if (leading >= childCount) leading = childCount - 1;
      collectGarbage(leading, trailing);
    }

    final double firstOffset = childScrollOffset(firstChild!)!;
    final double lastIndexEnd = model.offsetOf(indexOf(lastChild!) + 1);
    final double paintExtent =
        calculatePaintOffset(constraints, from: firstOffset, to: lastIndexEnd);
    final double cacheExtent =
        calculateCacheOffset(constraints, from: firstOffset, to: lastIndexEnd);
    final double total = model.total;
    geometry = SliverGeometry(
      scrollExtent: total,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: total,
      hasVisualOverflow:
          lastIndexEnd > scrollOffset + constraints.remainingPaintExtent ||
              scrollOffset > 0.0,
    );
    childManager.didFinishLayout();
    _publishFromChildren(off);
  }

  void _publishFromChildren(ScrollPosition? off) {
    final double viewport = _viewportExtent.isFinite
        ? _viewportExtent
        : math.max(geometry!.paintExtent, 1.0);
    final double pixels = off?.pixels ?? 0;
    final double sliverTop = math.max(0.0, _preceding - pixels);
    final List<IndexedItemPosition> result = <IndexedItemPosition>[];
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      final int raw = indexOf(c);
      if (_separated && raw.isOdd) continue;
      final double extent = _extentOfChild(c);
      final double pos = sliverTop + childMainAxisPosition(c);
      if (pos + extent <= precisionErrorTolerance ||
          pos >= viewport - precisionErrorTolerance) {
        continue;
      }
      result.add(IndexedItemPosition(
        index: _separated ? raw ~/ 2 : raw,
        leadingEdge: pos / viewport,
        trailingEdge: (pos + extent) / viewport,
      ));
    }
    _publish(result);
  }

  void _publish(List<IndexedItemPosition> result) {
    if (listEquals(result, _pendingPositions ?? _positions)) return;
    _pendingPositions = result;
    _schedulePostFrame();
  }
}
