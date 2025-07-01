import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/widgets/sidebar/resizable_sidebar.dart';

class AdaptiveMenuLayout extends ConsumerWidget {
  const AdaptiveMenuLayout({super.key, required this.menu, required this.body});
  final Widget menu;
  final Widget body;

  final double breakpoint = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuWithKey = KeyedSubtree(key: const ValueKey('menu'), child: menu);
    final bodyWithKey = KeyedSubtree(key: const ValueKey('body'), child: body);

    final double viewWidth = MediaQuery.sizeOf(context).width;
    final bool isWideScreen = viewWidth > breakpoint;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shouldHaveDrawer = !isWideScreen;
      if (ref.read(hasDrawerProvider) != shouldHaveDrawer) {
        ref.read(hasDrawerProvider.notifier).state = shouldHaveDrawer;
      }
    });

    return Scaffold(
      drawer: !isWideScreen ? Drawer(child: menuWithKey) : null,
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: viewWidth,

      body:
          isWideScreen
              ? Row(
                children: [
                  ResizableSidebar(
                    collapsible: true,
                    collapsedSize: 64,
                    collapsed: ref.read(sidebarCollapsedProvider),
                    width: ref.read(sidebarWidthProvider),
                    onCollapseChanged:
                        (isCollapsed) =>
                            ref.read(sidebarCollapsedProvider.notifier).state =
                                isCollapsed,
                    onResize:
                        (width) =>
                            ref.read(sidebarWidthProvider.notifier).state =
                                width,
                    child: menuWithKey,
                  ),
                  Expanded(child: bodyWithKey),
                ],
              )
              : bodyWithKey,
    );
  }
}
