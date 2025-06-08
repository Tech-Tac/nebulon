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
    final double viewWidth = MediaQuery.sizeOf(context).width;
    final bool isWideScreen = viewWidth > breakpoint;

    if (ref.read(hasDrawerProvider) != !isWideScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(hasDrawerProvider.notifier).state = !isWideScreen;
      });
    }

    return Scaffold(
      drawer: !isWideScreen ? Drawer(child: menu) : null,
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
                    child: menu,
                  ),
                  Expanded(child: body),
                ],
              )
              : body,
    );
  }
}
