import 'package:flutter/foundation.dart';

/// A simple service to manage the global gesture state for the timeline.
/// This prevents conflicts between scrolling the timeline and trimming a clip.
class GestureNotifier extends ChangeNotifier {
  bool _isTrimming = false;

  /// Returns true if a trimming gesture is currently active.
  bool get isTrimming => _isTrimming;

  /// Call this when a trim gesture begins.
  void startTrimming() {
    if (!_isTrimming) {
      _isTrimming = true;
      notifyListeners();
    }
  }

  /// Call this when a trim gesture ends.
  void stopTrimming() {
    if (_isTrimming) {
      _isTrimming = false;
      notifyListeners();
    }
  }
}
