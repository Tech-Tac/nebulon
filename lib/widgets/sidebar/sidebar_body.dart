import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:nebulon/providers/providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/widgets/sidebar/channel_list.dart';
import 'package:nebulon/widgets/sidebar/dm_list.dart';
import 'package:nebulon/widgets/sidebar/guild_list.dart';
import 'package:nebulon/widgets/sidebar/user_menu.dart';

import 'package:window_manager/window_manager.dart';

class SidebarMenu extends ConsumerStatefulWidget {
  const SidebarMenu({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => SidebarMenuState();
}

class SidebarMenuState extends ConsumerState<SidebarMenu>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    log("Building SidebarMenu");

    final selectedGuild = ref.watch(selectedGuildProvider);
    final screenPadding = MediaQuery.paddingOf(context);
    final isSidebarCollapsed = ref.watch(menuCollapsedProvider);

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(width: 64, child: const GuildList()),
              Expanded(
                child: Column(
                  children: [
                    DragToMoveArea(
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: EdgeInsets.only(top: screenPadding.top),
                          child: SizedBox(
                            height: 48,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: 8,
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectedGuild != null
                                          ? selectedGuild.name
                                          : "Direct Messages",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium!.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSecondaryContainer,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: Material(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child:
                            selectedGuild != null
                                ? ChannelList(guild: selectedGuild)
                                : const DMList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        UserMenuCard(collapsed: isSidebarCollapsed),
      ],
    );
  }
}
