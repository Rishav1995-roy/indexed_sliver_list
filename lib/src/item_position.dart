/// Where one item currently sits inside the viewport.
///
/// Edges are fractions of the viewport's main-axis extent measured in the
/// scroll direction: `0.0` is the viewport's leading edge, `1.0` its trailing
/// edge. Values can be negative or larger than `1.0` for partly visible items.
class IndexedItemPosition {
  /// Creates a position record.
  const IndexedItemPosition({
    required this.index,
    required this.leadingEdge,
    required this.trailingEdge,
  });

  /// Index of the item in the list (separators are not reported).
  final int index;

  /// Fraction of the viewport at which the item starts.
  final double leadingEdge;

  /// Fraction of the viewport at which the item ends.
  final double trailingEdge;

  /// Whether the whole item is inside the viewport.
  bool get isFullyVisible => leadingEdge >= -1e-6 && trailingEdge <= 1 + 1e-6;

  @override
  bool operator ==(Object other) =>
      other is IndexedItemPosition &&
      other.index == index &&
      (other.leadingEdge - leadingEdge).abs() < 1e-6 &&
      (other.trailingEdge - trailingEdge).abs() < 1e-6;

  @override
  int get hashCode =>
      Object.hash(index, leadingEdge.round(), trailingEdge.round());

  @override
  String toString() =>
      'IndexedItemPosition(index: $index, leading: ${leadingEdge.toStringAsFixed(3)}, '
      'trailing: ${trailingEdge.toStringAsFixed(3)})';
}

/// The first and last item that intersect the viewport.
class IndexedVisibleRange {
  /// Creates a range.
  const IndexedVisibleRange(this.first, this.last);

  /// Lowest visible item index.
  final int first;

  /// Highest visible item index.
  final int last;

  @override
  bool operator ==(Object other) =>
      other is IndexedVisibleRange &&
      other.first == first &&
      other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => 'IndexedVisibleRange($first..$last)';
}
