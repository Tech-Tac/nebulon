import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

final _kIsLinux = !kIsWeb && Platform.isLinux;
final _kIsWindows = !kIsWeb && Platform.isWindows;

class WindowFrame extends StatefulWidget {
  const WindowFrame({super.key, required this.child});

  /// The [child] contained by the WindowFrame.
  final Widget child;

  @override
  State<StatefulWidget> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> with WindowListener {
  /// The amount of space around the window in pixels where the user can drag to resize
  final double resizeEdgeSize = 8;

  /// The visible width of the border
  final double borderWidth = 1;

  /// The border radius of the window
  final double borderRadius = 6;

  bool _isFocused = true;
  bool _isMaximized = false;
  bool _isFullScreen = false;

  /// Should the window have a frame given current state?
  bool get shouldHaveFrame => !_isMaximized && !_isFullScreen;

  /// Does the platform give resize edges to undecorated windows or should we make one?
  // TODO: this should also be true on linux x11 as wayland has resizers by default
  bool get selfBuildResizer => _kIsWindows;

  /// Does the platform automatically draw borders to the window or should we draw them?
  bool get selfDrawOutline => _kIsLinux;

  /// Add transparent space around the window so the resize edges are on the outside of the window rather than inside
  double get resizeEdgeOutset => selfBuildResizer ? resizeEdgeSize : 0;

  @override
  void initState() {
    _initWindowState();
    windowManager.addListener(this);
    super.initState();
  }

  Future<void> _initWindowState() async {
    _isFocused = await windowManager.isFocused();
    _isMaximized = await windowManager.isMaximized();
    _isFullScreen = await windowManager.isFullScreen();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Widget _buildBorder() {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final lightColor = _isFocused ? Colors.grey.shade700 : Colors.grey.shade600;
    final darkColor = _isFocused ? Colors.grey.shade800 : Colors.grey.shade900;
    final color = isLightMode ? lightColor : darkColor;

    return DecoratedBox(
      // this box determines the color of the border
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(borderWidth), // this offset makes the border
        child: ClipRRect(
          // make content border radius smaller for border width to be consistent at corners
          borderRadius: BorderRadius.circular(
            max(borderRadius - borderWidth, 0),
          ),
          child: widget.child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldHaveFrame || (!selfDrawOutline && !selfBuildResizer)) {
      // nothing to do
      return widget.child;
    }

    final Widget window = selfDrawOutline ? _buildBorder() : widget.child;

    return selfBuildResizer
        ? DragToResizeArea(
          resizeEdgeSize: resizeEdgeSize,
          // windows smh
          enableResizeEdges:
              _kIsWindows
                  ? [ResizeEdge.topLeft, ResizeEdge.top, ResizeEdge.topRight]
                  : null,
          child: Padding(
            // the actual border should also allow resizing
            padding: EdgeInsets.all(max(resizeEdgeOutset - borderWidth, 0)),
            child: window,
          ),
        )
        : window;
  }

  @override
  void onWindowFocus() {
    setState(() {
      _isFocused = true;
    });
  }

  @override
  void onWindowBlur() {
    setState(() {
      _isFocused = false;
    });
  }

  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() {
      _isFullScreen = true;
    });
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() {
      _isFullScreen = false;
    });
  }
}
