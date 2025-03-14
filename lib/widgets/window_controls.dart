import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nebulon/widgets/window_move_area.dart';

import 'package:universal_platform/universal_platform.dart';
import 'package:window_manager/window_manager.dart';

enum WindowButtonShape {
  circle,
  box;

  static WindowButtonShape platformDefault =
      (UniversalPlatform.isWindows
          ? WindowButtonShape.box
          : WindowButtonShape.circle);
}

class WindowButton extends StatefulWidget {
  const WindowButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.shape,
    this.size,
    this.iconSize,
    this.spacing,
    this.hoverTransitionDuration,
    this.color,
    this.hoverColor,
    this.iconColor,
    this.iconHoverColor,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final WindowButtonShape? shape;
  final double? size;
  final double? iconSize;
  final double? spacing;
  final Duration? hoverTransitionDuration;
  final Color? color;
  final Color? hoverColor;
  final Color? iconColor;
  final Color? iconHoverColor;

  @override
  State<StatefulWidget> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final WindowButtonShape shape =
        widget.shape ?? WindowButtonShape.platformDefault;

    // The default button styling on Windows is a 48 pixel-wide box with no margins, while on
    // other platforms it's a 24 pixel-wide circle with 4 pixels of (clickable) margin around each.

    final bool isCircle = shape == WindowButtonShape.circle;
    final Duration hoverTransitionDuration =
        widget.hoverTransitionDuration ?? const Duration(milliseconds: 150);
    final double spacing = widget.spacing ?? (isCircle ? 4 : 0);
    final double width = widget.size ?? (isCircle ? 20 : 48);
    final double? height = (isCircle ? widget.size ?? 24 : null);
    final double iconSize = min(widget.iconSize ?? 16, width);
    final Color hoverColor =
        widget.hoverColor ?? widget.color ?? Theme.of(context).highlightColor;
    final Color color = widget.color ?? hoverColor.withAlpha(0);

    return GestureDetector(
      onTap: widget.onPressed,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: hoverTransitionDuration,
          width: width,
          height: height,
          margin:
              spacing > 0 ? EdgeInsets.symmetric(horizontal: spacing) : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            color: _isHovered ? hoverColor : color,
          ),
          child: IconTheme(
            data: IconTheme.of(context).copyWith(
              size: iconSize,
              color: _isHovered ? widget.iconHoverColor : widget.iconColor,
            ),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}

class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _isFocused = true;
  bool _isFullscreen = false;
  bool _isMaximized = false;

  @override
  void initState() {
    windowManager.addListener(this);
    _updateControls();
    super.initState();
  }

  void _updateControls() async {
    final windowState = await Future.wait([
      windowManager.isFocused(),
      windowManager.isFullScreen(),
      windowManager.isMaximized(),
    ]);
    if (!mounted) return;
    setState(() {
      _isFocused = windowState[0];
      _isFullscreen = windowState[1];
      _isMaximized = windowState[2];
    });
  }

  @override
  void onWindowFocus() => setState(() => _isFocused = true);
  @override
  void onWindowBlur() => setState(() => _isFocused = false);
  @override
  void onWindowEnterFullScreen() => setState(() => _isFullscreen = true);
  @override
  void onWindowLeaveFullScreen() => setState(() => _isFullscreen = false);
  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);
  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  List<Widget> _buildNormalButtons(BuildContext context) {
    return [
      WindowButton(
        onPressed: windowManager.minimize,
        icon: Icon(Icons.horizontal_rule),
      ),

      if (_isFullscreen)
        WindowButton(
          onPressed: () => windowManager.setFullScreen(false),
          icon: Icon(Icons.fullscreen_exit),
        )
      else
        WindowButton(
          icon: Icon(
            _isMaximized ? Icons.square_rounded : Icons.crop_square_rounded,
          ),
          onPressed:
              _isMaximized ? windowManager.unmaximize : windowManager.maximize,
        ),

      WindowButton(
        onPressed: windowManager.close,
        icon: Icon(Icons.close),
        hoverColor: Color(0xFFDD0000),
      ),
    ];
  }

  List<Widget> _buildMacOSButtons(BuildContext context) {
    final Color nonFocusColor = Colors.grey;
    final closeColor = Colors.red;
    final minColor = Colors.yellow;
    final maxColor = Colors.green;

    final Color iconColor = Colors.transparent;
    final Color iconHoverColor = Colors.black;

    final double size = 12;
    final double spacing = 4;

    return [
      WindowButton(
        onPressed: windowManager.close,
        icon: Icon(Icons.close),
        iconHoverColor: iconHoverColor,
        color: _isFocused ? closeColor : nonFocusColor,
        hoverColor: closeColor,
        iconColor: iconColor,
        size: size,
        spacing: spacing,
      ),

      WindowButton(
        onPressed: windowManager.minimize,

        icon: Icon(Icons.horizontal_rule),
        iconHoverColor: iconHoverColor,
        color: _isFocused ? minColor : nonFocusColor,
        hoverColor: minColor,
        iconColor: iconColor,
        size: size,
        spacing: spacing,
      ),

      WindowButton(
        icon: Icon(
          _isFullscreen || _isMaximized
              ? Icons.close_fullscreen
              : Icons.fullscreen,
        ),
        onPressed:
            _isFullscreen
                ? () => windowManager.setFullScreen(false)
                : _isMaximized
                ? windowManager.unmaximize
                : windowManager.maximize,

        iconHoverColor: iconHoverColor,
        color: _isFocused ? maxColor : nonFocusColor,
        hoverColor: maxColor,
        iconColor: iconColor,
        size: size,
        spacing: spacing,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) {},
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.end,
        children:
            UniversalPlatform.isMacOS
                ? _buildMacOSButtons(context)
                : _buildNormalButtons(context),
      ),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}

class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    this.title,
    this.icon,
    this.color,
    this.height = 48,
    this.showWindowControls = true,
    this.startActions,
    this.endActions,
  });
  final Widget? title;
  final Widget? icon;
  final Color? color;
  final double height;
  final bool showWindowControls;
  final List<Widget>? startActions;
  final List<Widget>? endActions;

  @override
  Widget build(BuildContext context) {
    final screenPadding = MediaQuery.of(context).padding;

    return WindowMoveArea(
      child: ColoredBox(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: EdgeInsets.only(top: screenPadding.top),
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                if (showWindowControls && UniversalPlatform.isMacOS)
                  WindowControls(),

                if (startActions != null) ...startActions!,

                Expanded(
                  child: SizedBox.expand(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 8,
                        children: [
                          if (icon != null) icon!,
                          if (title != null)
                            Expanded(
                              child: DefaultTextStyle(
                                style: Theme.of(context).textTheme.titleMedium!,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                child: title!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (endActions != null) ...endActions!,

                if (showWindowControls &&
                    !UniversalPlatform.isMacOS &&
                    UniversalPlatform.isDesktop)
                  WindowControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
