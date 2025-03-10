import 'package:flutter/material.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/guild.dart';

import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/helpers/cdn_image.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/widgets/user_menu.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
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

    final selectedGuild = ref.watch(selectedGuildProvider);
    final screenPadding = MediaQuery.of(context).padding;
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

class GuildList extends ConsumerWidget {
  const GuildList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guilds = ref.watch(guildsProvider);
    final selectedGuild = ref.watch(selectedGuildProvider);
    final selectedGuildNotifier = ref.read(selectedGuildProvider.notifier);

    final screenPadding = MediaQuery.of(context).padding;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SuperListView.builder(
        padding:
            const EdgeInsets.symmetric(vertical: 8) +
            EdgeInsets.only(left: screenPadding.left, top: screenPadding.top),

        itemCount: guilds.length + 1,
        itemBuilder: (itemContext, index) {
          if (index == 0) {
            return Column(
              spacing: 4,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SidebarItem(
                    item: const Icon(Icons.chat_bubble),
                    text: "Direct Messages",
                    isSelected: selectedGuild == null,
                    onTap: () => selectedGuildNotifier.set(null),
                  ),
                ),

                Divider(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(64),
                  thickness: 0.5,
                  indent: 16,
                  endIndent: 16,
                ),
              ],
            );
          }
          final guild = guilds[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SidebarItem(
              image:
                  guild.iconHash != null
                      ? cdnImage(
                        context,
                        "icons/${guild.id}/${guild.iconHash!}.png",
                        size: 48,
                      )
                      : null,
              text: guild.name,
              onTap: () => selectedGuildNotifier.set(guild),
              isSelected: selectedGuild == guild,
              hasDot: true,
            ),
          );
        },
      ),
    );
  }
}

class DMList extends StatelessWidget {
  const DMList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [],
    );
  }
}

class ChannelList extends StatelessWidget {
  final GuildModel guild;
  const ChannelList({super.key, required this.guild});

  @override
  Widget build(BuildContext context) {
    final channels = [...guild.channels];

    // sort the channels where uncategorized channels are
    // before categories and voice channels are last.
    channels.sort((a, b) {
      const num defaultPosition =
          double.infinity; // channel with no position come last

      int getGroup(ChannelModel item) {
        // voice channels always come last
        if (item.type.isVoice) return 3;
        // categories second
        if (item.type == ChannelType.category) return 1;
        // uncategorized channels at the very top
        if (item.parentId == null && item.type != ChannelType.category) {
          return 0;
        }
        // and then everything else
        return 2;
      }

      final groupA = getGroup(a);
      final groupB = getGroup(b);

      // if channels fall into different groups, sort by group.
      if (groupA != groupB) {
        return groupA.compareTo(groupB);
      }

      // Otherwise, sort by position (treating null as last).
      final posA = a.position ?? defaultPosition;
      final posB = b.position ?? defaultPosition;
      return posA.compareTo(posB);
    });

    final channelTree = <ChannelModel, List<ChannelModel>>{};

    for (var channel in channels) {
      final ChannelModel? parent = channel.parent;
      if (parent == null) {
        channelTree[channel] = [];
      } else {
        channelTree[parent] ??= [];
        channelTree[parent]!.add(channel);
      }
    }

    // should any of the above even be in build()?

    return SuperListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channelTree.length,
      itemBuilder: (context, index) {
        final rootChannel = channelTree.keys.elementAt(index);
        final List<ChannelModel> children = channelTree.values.elementAt(index);
        return rootChannel.type == ChannelType.category
            ? ChannelCategory(
              title: rootChannel.displayName,
              id: rootChannel.id,
              channels: children,
            )
            : ChannelTile(channel: rootChannel);
      },
    );
  }
}

class ChannelCategory extends StatelessWidget {
  const ChannelCategory({
    super.key,
    required this.title,
    this.id,
    required this.channels,
  });
  final String title;
  final dynamic id;
  final List<ChannelModel> channels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // channel categories
      child: ExpansionTile(
        key: PageStorageKey("${id}_channel_category"),
        title: Text(title),
        initiallyExpanded: true,
        dense: true,
        shape: const Border(),
        children: [
          SuperListView.builder(
            key: PageStorageKey("Category list $id"),
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              return ChannelTile(channel: channels[index]);
            },
          ),
        ],
      ),
    );
  }
}

class ChannelTile extends ConsumerWidget {
  final ChannelModel channel;

  const ChannelTile({super.key, required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isSelected = ref.watch(selectedChannelProvider) == channel;
    final selectedChannelNotifier = ref.read(selectedChannelProvider.notifier);

    return ListTile(
      title: Text(channel.displayName, overflow: TextOverflow.ellipsis),
      leading: Icon(getChannelSymbol(channel.type)),
      selected: isSelected,
      onTap: () {
        selectedChannelNotifier.set(channel);
        Scaffold.of(context).closeDrawer();
      },
      dense: true,
      titleTextStyle: Theme.of(context).textTheme.bodyMedium,
      minTileHeight: 32,
      horizontalTitleGap: 8,
      iconColor: Theme.of(context).colorScheme.onSurface.withAlpha(176),
      textColor: Theme.of(context).colorScheme.onSurface.withAlpha(200),
      selectedTileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      selectedColor: Theme.of(context).colorScheme.onSurface,
    );
  }
}

class SidebarItem extends ConsumerStatefulWidget {
  final Widget? item;
  final ImageProvider? image;
  final String? text;
  final Function()? onTap;
  final bool isSelected;
  final bool hasDot;

  const SidebarItem({
    super.key,
    this.item,
    this.image,
    this.text,
    this.onTap,
    this.isSelected = false,
    this.hasDot = false,
  });

  @override
  ConsumerState<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends ConsumerState<SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
      },
      cursor: SystemMouseCursors.click,
      child: InkWell(
        enableFeedback: false,
        onHover: (state) => setState(() => _isHovered = state),
        onFocusChange: (state) => setState(() => _isHovered = state),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.isSelected || _isHovered ? 16 : 24,
            ),
            color:
                widget.image == null
                    ? (widget.isSelected || _isHovered
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest)
                    : Colors.transparent,
            image:
                widget.image != null
                    ? DecorationImage(image: widget.image!, fit: BoxFit.fill)
                    : null,
          ),
          child: widget.item,
        ),
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        widget.text != null
            ? Tooltip(message: widget.text, child: button)
            : button,
        Positioned(
          left: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: widget.isSelected || _isHovered || widget.hasDot ? 4 : 0,
            height:
                widget.isSelected
                    ? 40
                    : _isHovered
                    ? 20
                    : widget.hasDot
                    ? 8
                    : 0,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
