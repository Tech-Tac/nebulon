import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

final _kIsLinux = !kIsWeb && Platform.isLinux;
final _kIsWindows = !kIsWeb && Platform.isWindows;

class WindowFrame extends StatefulWidget {
  const WindowFrame({super.key, required this.child});

  /// The [child] contained by the VirtualWindowFrame.
  final Widget child;

  @override
  State<StatefulWidget> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> with WindowListener {
  bool _isFocused = true;
  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool get showBorder => !_isMaximized && !_isFullScreen;

  final double resizeEdgeSize = 8;
  final double borderWidth = 1;
  final double borderRadius = 6;
  final double resizeEdgeOutset = 0; // should be resizeEdgeSize

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Widget _buildBorder() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            _isFocused
                ? Theme.of(context).colorScheme.surfaceBright
                : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(borderWidth),
        child: ClipRRect(
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
    if (!showBorder || (!_kIsLinux && !_kIsWindows)) return widget.child;

    return _kIsLinux
        ? _buildBorder()
        : DragToResizeArea(
          resizeEdgeSize: resizeEdgeSize,
          enableResizeEdges:
              _kIsWindows
                  ? [ResizeEdge.topLeft, ResizeEdge.top, ResizeEdge.topRight]
                  : null,
          child: Padding(
            padding: EdgeInsets.all(max(resizeEdgeOutset - borderWidth, 0)),
            child: widget.child,
          ),
        );
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
