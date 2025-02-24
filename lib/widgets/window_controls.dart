import 'package:flutter/material.dart';
import 'package:nebulon/providers/providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final Color hoverColor =
        widget.hoverColor ?? Theme.of(context).highlightColor;
    final double spacing = widget.spacing ?? (isCircle ? 3 : 0);
    final double width = widget.size ?? (isCircle ? 24 : 48);
    final double? height = (isCircle ? widget.size ?? 24 : null);
    final double iconSize = widget.iconSize ?? 16;

    return GestureDetector(
      onTap: widget.onPressed,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          width: width,
          height: height,
          margin:
              spacing > 0 ? EdgeInsets.symmetric(horizontal: spacing) : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            color:
                _isHovered
                    ? hoverColor
                    : (widget.color ?? hoverColor.withAlpha(0)),
          ),
          child: IconTheme(
            data: IconTheme.of(context).copyWith(
              size: iconSize,
              color: _isHovered ? widget.iconColor : widget.iconHoverColor,
            ),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}

class WindowCloseButton extends StatelessWidget {
  const WindowCloseButton({super.key});
  @override
  Widget build(_) => WindowButton(
    onPressed: windowManager.close,
    icon: Icon(Icons.close),
    hoverColor: Color(0xFFDD0000),
  );
}

class WindowMaximizeButton extends StatelessWidget {
  const WindowMaximizeButton({super.key, this.maximized = false});
  final bool maximized;
  @override
  Widget build(_) => WindowButton(
    icon: Icon(maximized ? Icons.square_rounded : Icons.crop_square_rounded),
    onPressed: maximized ? windowManager.unmaximize : windowManager.maximize,
  );
}

class WindowMinimizeButton extends StatelessWidget {
  const WindowMinimizeButton({super.key});
  @override
  Widget build(_) => WindowButton(
    onPressed: windowManager.minimize,
    icon: Icon(Icons.horizontal_rule),
  );
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onPanStart: (_) {},
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 100),
        curve: Curves.linear,
        opacity: _isFocused ? 1 : 0.5,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            WindowMinimizeButton(),
            if (_isFullscreen)
              WindowButton(
                onPressed: () => windowManager.setFullScreen(false),
                icon: Icon(Icons.fullscreen_exit),
              )
            else
              WindowMaximizeButton(maximized: _isMaximized),
            WindowCloseButton(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}

class TitleBar extends ConsumerWidget {
  const TitleBar({super.key, this.title, this.icon, this.color});
  final Widget? title;
  final Widget? icon;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasDrawer = ref.watch(hasDrawerProvider);

    final screenPadding = MediaQuery.of(context).padding;

    return Container(
      height: 48,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.only(
          top: screenPadding.top,
          right: screenPadding.right,
        ),
        child: Row(
          children: [
            if (UniversalPlatform.isMacOS) WindowControls(),
            if (hasDrawer)
              IconButton(
                onPressed: Scaffold.of(context).openDrawer,
                icon: Icon(Icons.menu),
              ),
            Expanded(
              child: DragToMoveArea(
                child: Container(
                  height: double.infinity,
                  padding: EdgeInsets.only(left: hasDrawer ? 0 : 8),
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
                            child: title!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (UniversalPlatform.isDesktop && !UniversalPlatform.isMacOS)
              WindowControls(),
          ],
        ),
      ),
    );
  }
}
