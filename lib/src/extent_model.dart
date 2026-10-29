/// Tracks the main-axis extent of every item of a lazily built list.
///
/// Items that have never been laid out are *unknown*; their extent is assumed
/// to be [estimate], the mean of every known extent (or the initial estimate
/// until something was measured). All offset queries run in `O(log n)` thanks
/// to two Fenwick trees (sum of known extents, count of known items).
///
/// This class is pure Dart and has no dependency on Flutter.
class ExtentModel {
  /// Creates a model whose unknown items count as [initialEstimate] until the
  /// first item has been measured.
  ExtentModel({double initialEstimate = 100.0, int length = 0})
      : assert(initialEstimate > 0),
        _initialEstimate = initialEstimate {
    resize(length);
  }

  final double _initialEstimate;
  List<double> _extents = <double>[]; // NaN means unknown
  List<double> _sumTree = <double>[0];
  List<int> _countTree = <int>[0];
  double _knownSum = 0;
  int _knownCount = 0;

  /// Number of items tracked.
  int get length => _extents.length;

  /// Number of items whose real extent is known.
  int get knownCount => _knownCount;

  /// Extent assumed for items that were never measured.
  double get estimate =>
      _knownCount == 0 ? _initialEstimate : _knownSum / _knownCount;

  /// Total extent of all items (exact once everything was measured).
  double get total => _knownSum + (length - _knownCount) * estimate;

  /// Whether item [index] has been measured.
  bool isKnown(int index) => !_extents[index].isNaN;

  /// Extent of item [index]: the measured value or the current [estimate].
  double extentOf(int index) {
    final double e = _extents[index];
    return e.isNaN ? estimate : e;
  }

  /// Records the measured [extent] of item [index]. Returns whether the model
  /// changed.
  bool setExtent(int index, double extent) {
    final double old = _extents[index];
    if (!old.isNaN && (old - extent).abs() < 1e-6) return false;
    _extents[index] = extent;
    if (old.isNaN) {
      _knownCount++;
      _knownSum += extent;
      _add(index, extent, 1);
    } else {
      _knownSum += extent - old;
      _add(index, extent - old, 0);
    }
    return true;
  }

  /// Offset of the leading edge of item [index] (`index == length` gives
  /// [total]).
  double offsetOf(int index) {
    assert(index >= 0 && index <= length);
    double sum = 0;
    int count = 0;
    for (int i = index; i > 0; i -= i & -i) {
      sum += _sumTree[i];
      count += _countTree[i];
    }
    return sum + (index - count) * estimate;
  }

  /// Index of the item covering [offset] (the last item starting at or before
  /// it), clamped to the valid range. Returns 0 for an empty model.
  int indexAt(double offset) {
    if (length == 0) return 0;
    int lo = 0;
    int hi = length - 1;
    while (lo < hi) {
      final int mid = (lo + hi + 1) >> 1;
      if (offsetOf(mid) <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Grows (with unknown items) or shrinks the model to [newLength].
  void resize(int newLength) {
    assert(newLength >= 0);
    if (newLength == length && _sumTree.length == newLength + 1) return;
    if (newLength < length) {
      _extents = _extents.sublist(0, newLength);
    } else {
      _extents = <double>[
        ..._extents,
        ...List<double>.filled(newLength - length, double.nan),
      ];
    }
    _rebuild();
  }

  /// Inserts [count] unknown items before [index].
  void insert(int index, int count) {
    assert(index >= 0 && index <= length && count >= 0);
    if (count == 0) return;
    _extents = <double>[
      ..._extents.sublist(0, index),
      ...List<double>.filled(count, double.nan),
      ..._extents.sublist(index),
    ];
    _rebuild();
  }

  /// Removes up to [count] items starting at [index].
  void remove(int index, int count) {
    assert(index >= 0 && count >= 0);
    if (count == 0 || index >= length) return;
    final int end = (index + count).clamp(0, length);
    _extents = <double>[
      ..._extents.sublist(0, index),
      ..._extents.sublist(end)
    ];
    _rebuild();
  }

  /// Forgets every measurement.
  void clear() {
    final int n = length;
    _extents = List<double>.filled(n, double.nan);
    _rebuild();
  }

  void _rebuild() {
    final int n = _extents.length;
    _sumTree = List<double>.filled(n + 1, 0);
    _countTree = List<int>.filled(n + 1, 0);
    _knownSum = 0;
    _knownCount = 0;
    for (int i = 0; i < n; i++) {
      final double e = _extents[i];
      if (!e.isNaN) {
        _knownSum += e;
        _knownCount++;
        _sumTree[i + 1] += e;
        _countTree[i + 1] += 1;
      }
      final int parent = (i + 1) + ((i + 1) & -(i + 1));
      if (parent <= n) {
        _sumTree[parent] += _sumTree[i + 1];
        _countTree[parent] += _countTree[i + 1];
      }
    }
  }

  void _add(int index, double sumDelta, int countDelta) {
    for (int i = index + 1; i < _sumTree.length; i += i & -i) {
      _sumTree[i] += sumDelta;
      _countTree[i] += countDelta;
    }
  }
}
