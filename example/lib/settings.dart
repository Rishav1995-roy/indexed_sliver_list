import 'package:flutter/material.dart';

/// Everything the "Customize" tab can change.
class DemoSettings extends ChangeNotifier {
  double _alignment = 0.0;
  bool _separators = true;
  bool _animate = true;
  double _estimate = 140;
  Color _seed = Colors.indigo;
  bool _horizontal = false;

  /// Alignment used for every jump (0 = top, 1 = bottom).
  double get alignment => _alignment;
  set alignment(double v) => _set(() => _alignment = v);

  /// Draw separators between cards.
  bool get separators => _separators;
  set separators(bool v) => _set(() => _separators = v);

  /// Animate (true) or jump (false) from the feed buttons.
  bool get animate => _animate;
  set animate(bool v) => _set(() => _animate = v);

  /// `estimatedItemExtent` passed to the list.
  double get estimate => _estimate;
  set estimate(double v) => _set(() => _estimate = v);

  /// Seed color of the app theme.
  Color get seed => _seed;
  set seed(Color v) => _set(() => _seed = v);

  /// Show the feed horizontally.
  bool get horizontal => _horizontal;
  set horizontal(bool v) => _set(() => _horizontal = v);

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}
