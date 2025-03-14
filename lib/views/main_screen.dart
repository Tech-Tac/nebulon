import 'package:flutter/material.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/views/channel/channel_view.dart';
import 'package:nebulon/views/sidebar_view.dart';
import 'package:nebulon/widgets/resizable_sidebar.dart';
import 'package:nebulon/widgets/window_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_platform/universal_platform.dart';
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
    final ChannelModel? selectedChannel = ref.watch(selectedChannelProvider);
    final bool hasDrawer = ref.watch(hasDrawerProvider);

    final String? title = selectedChannel?.displayName;

    windowManager.setTitle(["Nebulon", if (title != null) title].join(" | "));

    return Column(
      children: [
        TitleBar(
          icon:
              selectedChannel == null
                  ? const Icon(
                    Icons.discord,
                  ) // this is a placeholder until I design a logo
                  : Icon(getChannelSymbol(selectedChannel.type)),
          title: Text(title ?? "Nebulon"),
          startActions: [
            if (hasDrawer)
              IconButton(
                onPressed: Scaffold.of(context).openDrawer,
                icon: Icon(Icons.menu),
              ),
          ],
          // the title-bar is not left aligned, we will put the controls on the left sidebar instead
          showWindowControls: !UniversalPlatform.isMacOS,
        ),
        Expanded(child: MainChannelView()),
      ],
    );
  }
}
