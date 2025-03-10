import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/src/window_manager.dart';

/// A widget for drag to move window.
///
/// When you have hidden the title bar, you can add this widget to move the window position.
///
/// {@tool snippet}
///
/// The sample creates a red box, drag the box to move the window.
///
/// ```dart
/// WindowMoveArea(
///   child: Container(
///     width: 300,
///     height: 32,
///     color: Colors.red,
///   ),
/// )
/// ```
/// {@end-tool}
class WindowMoveArea extends StatelessWidget {
  const WindowMoveArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DoubleTapDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _toggleMaximized,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          windowManager.startDragging();
        },
        child: child,
      ),
    );
  }
}

void _toggleMaximized() async {
  bool isMaximized = await windowManager.isMaximized();
  if (!isMaximized) {
    windowManager.maximize();
  } else {
    windowManager.unmaximize();
  }
}

/// Detects doubleTaps without introducing single-tap trigger delay to children,
/// at the cost of not triggering on doubleTap if the child listens for onTap.
class DoubleTapDetector extends StatefulWidget {
  const DoubleTapDetector({
    super.key,
    this.behavior,
    required this.onDoubleTap,
    required this.child,
  });

  final HitTestBehavior? behavior;
  final VoidCallback onDoubleTap;
  final Widget child;

  @override
  State<DoubleTapDetector> createState() => _DoubleTapDetectorState();
}

class _DoubleTapDetectorState extends State<DoubleTapDetector> {
  int lastTapTimestamp = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: () {
        final int now = DateTime.now().millisecondsSinceEpoch;
        if (lastTapTimestamp != 0 &&
            now - lastTapTimestamp <= kDoubleTapTimeout.inMilliseconds) {
          widget.onDoubleTap();
          lastTapTimestamp = 0;
        } else {
          lastTapTimestamp = now;
        }
      },
      child: widget.child,
    );
  }
}
