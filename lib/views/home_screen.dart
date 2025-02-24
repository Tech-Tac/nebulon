import 'package:flutter/material.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/views/channel_view.dart';
import 'package:nebulon/views/sidebar_view.dart';
import 'package:nebulon/widgets/window_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final GlobalKey sidebarKey = GlobalKey<SidebarMenuState>();

  @override
  Widget build(BuildContext context) {
    return ResponsiveMenuLayout(
      menu: SidebarMenu(key: sidebarKey),
      body: ViewBody(),
    );
  }
}

class ResponsiveMenuLayout extends ConsumerWidget {
  const ResponsiveMenuLayout({
    super.key,
    required this.menu,
    required this.body,
  });
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
                    initialWidth: ref.read(sidebarWidthProvider),
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

class ViewBody extends ConsumerWidget {
  const ViewBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(apiServiceProvider);
    final ChannelModel? selectedChannel = ref.watch(selectedChannelProvider);

    final String? title = selectedChannel?.displayName;

    windowManager.setTitle(["Nebulon", if (title != null) title].join(" | "));

    return Column(
      children: [
        TitleBar(
          icon:
              selectedChannel == null
                  ? const Icon(Icons.discord)
                  : Icon(getChannelSymbol(selectedChannel.type)),
          title: Text(title ?? "Nebulon"),
        ),
        Expanded(child: MainChannelView()),
      ],
    );
  }
}
