import 'dart:async';
import 'package:flutter/material.dart';

class ResizableSidebar extends StatefulWidget {
  final Widget child;
  final double width;
  final double minWidth;
  final double maxWidth;
  final bool collapsible;
  final bool collapsed;
  final double collapsedSize;
  final Function(bool state)? onCollapseChanged;
  final Function(double width)? onResize;

  const ResizableSidebar({
    super.key,
    required this.child,
    this.width = 360,
    this.minWidth = 256,
    this.maxWidth = 512,
    this.collapsible = false,
    this.collapsed = false,
    this.collapsedSize = 0,
    this.onCollapseChanged,
    this.onResize,
  }) : assert(maxWidth > minWidth),
       assert(collapsedSize < minWidth),
       assert(collapsed ? collapsible : true);

  @override
  State<ResizableSidebar> createState() => ResizableSidebarState();
}

class ResizableSidebarState extends State<ResizableSidebar> {
  late double width;
  bool isCollapsed = false;
  bool _isResizerHovered = false;
  bool _isDragging = false;
  bool _isDragCanceled = false;
  Timer? _hoverTimer;

  @override
  void initState() {
    super.initState();
    width = widget.width;
    isCollapsed = widget.collapsed;
  }

  @override
  Widget build(BuildContext context) {
    Color hoverColor = Theme.of(context).colorScheme.secondary;

    return SizedBox(
      width: isCollapsed ? widget.collapsedSize : width,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => setState(() => _isDragging = true),
              onHorizontalDragUpdate: (details) {
                setState(() {
                  if (widget.collapsible &&
                      details.globalPosition.dx <=
                          widget.collapsedSize +
                              (widget.minWidth - widget.collapsedSize) / 2) {
                    if (!isCollapsed) {
                      isCollapsed = true;
                      if (widget.onCollapseChanged != null) {
                        widget.onCollapseChanged!(true);
                      }
                    }
                  } else if (details.globalPosition.dx <= widget.maxWidth) {
                    width = (details.globalPosition.dx).clamp(
                      widget.minWidth,
                      widget.maxWidth,
                    );
                    if (isCollapsed) {
                      isCollapsed = false;
                      if (widget.onCollapseChanged != null) {
                        widget.onCollapseChanged!(false);
                      }
                    }
                    if (widget.onResize != null) widget.onResize!(width);
                  }
                });
              },
              onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
              onHorizontalDragCancel:
                  () => setState(() {
                    _isDragging = false;
                    _isDragCanceled = true;
                  }),
              child: MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                opaque: false,
                cursor:
                    !_isDragCanceled
                        ? SystemMouseCursors.resizeLeftRight
                        : MouseCursor.defer,
                onEnter: (_) {
                  setState(() => _isDragCanceled = false);
                  _hoverTimer = Timer(
                    const Duration(milliseconds: 300),
                    () => setState(() => _isResizerHovered = true),
                  );
                },
                onExit:
                    (_) => setState(() {
                      _hoverTimer?.cancel();
                      _isResizerHovered = false;
                    }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                  width: 8,
                  color:
                      (_isDragging || _isResizerHovered) && !_isDragCanceled
                          ? hoverColor
                          : hoverColor.withAlpha(0),
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }
}
