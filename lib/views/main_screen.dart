import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nebulon/helpers/cdn_image.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/views/adaptive_menu_layout.dart';
import 'package:nebulon/views/channels/channel_view.dart';
import 'package:nebulon/widgets/sidebar/sidebar_body.dart';
import 'package:nebulon/widgets/window/window_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:window_manager/window_manager.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final GlobalKey sidebarKey = GlobalKey<SidebarMenuState>();

  @override
  Widget build(BuildContext context) {
    return AdaptiveMenuLayout(
      menu: SidebarMenu(key: sidebarKey),
      body: ViewBody(),
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

    windowManager.setTitle(
      [
        "Nebulon",
        if (kDebugMode) "Debug",
        if (title != null) title,
      ].join(" | "),
    );

    return Column(
      children: [
        TitleBar(
          icon:
              selectedChannel == null
                  ? const Icon(
                    Icons.discord,
                  ) // this is a placeholder until I design a logo
                  : selectedChannel.iconPath != null
                  ? CircleAvatar(
                    // to prevent fade-in animation when switching channels
                    key: ValueKey("${selectedChannel.id}-title-icon"),
                    backgroundImage: cdnImage(
                      context,
                      selectedChannel.iconPath!,
                      size: 32,
                    ),
                    radius: 16,
                  )
                  : Icon(getChannelSymbol(selectedChannel.type)),
          title: Text(title ?? "Nebulon"),
          startActions: [
            if (hasDrawer)
              IconButton(
                onPressed: Scaffold.of(context).openDrawer,
                icon: Icon(Icons.menu),
              ),
          ],
          endActions: [
            if (kDebugMode)
              Tooltip(
                message: "This is a debug build",
                child: Icon(Icons.bug_report),
              ),
          ],

          // the title-bar is not left aligned, we will put the controls on the left sidebar instead
          showWindowControls: !UniversalPlatform.isMacOS,
        ),
        Expanded(child: MainChannelView(key: ValueKey("main-channel-view"))),
      ],
    );
  }
}
