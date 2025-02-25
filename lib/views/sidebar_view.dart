import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/guild.dart';

import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/helpers/cdn_image.dart';
import 'package:nebulon/services/session_manager.dart';
import 'package:nebulon/widgets/message_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                      child: Container(
                        padding:
                            EdgeInsets.all(8) +
                            EdgeInsets.only(top: screenPadding.top),
                        height: 48 + screenPadding.top,
                        alignment: Alignment.center,
                        color: Theme.of(context).colorScheme.secondaryContainer,
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

                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
        UserCard(collapsed: isSidebarCollapsed),
      ],
    );
  }
}

class UserCard extends ConsumerStatefulWidget {
  const UserCard({super.key, required this.collapsed});

  final bool collapsed;

  @override
  ConsumerState<UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<UserCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 150),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  void _showPopup() {
    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              // Dismiss popup when tapping anywhere
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _removePopup(),
                  child: Container(),
                ),
              ),
              // Animated Popup positioned above the button
              Positioned(
                left: offset.dx,
                bottom: MediaQuery.of(context).size.height - offset.dy + 8,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceBright,
                    child: UserMenu(),
                  ),
                ),
              ),
            ],
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward(); // Start fade-in animation
  }

  void _removePopup() async {
    await _animationController.reverse(); // Play fade-out animation
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectedUser = ref.watch(connectedUserProvider);
    final screenPadding = MediaQuery.of(context).padding;
    return Material(
      color: Theme.of(context).colorScheme.surfaceBright,
      child: Container(
        height: 56 + screenPadding.bottom,
        padding:
            EdgeInsets.all(4) +
            EdgeInsets.only(
              bottom: screenPadding.bottom,
              left: screenPadding.left,
            ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 4,
          children: [
            Expanded(
              child: InkWell(
                key: _buttonKey,
                onTap: _showPopup,
                borderRadius: BorderRadius.circular(8),
                child: connectedUser.when(
                  data:
                      (user) => Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: Row(
                          spacing: 8,
                          children: [
                            UserAvatar(user: user, size: 40),
                            if (!widget.collapsed)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.displayName),
                                  Text(
                                    "Online",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall!.copyWith(
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                  loading: () {
                    return Center(child: CircularProgressIndicator());
                  },
                  error:
                      (error, stackTrace) =>
                          Center(child: Text("Error loading user")),
                ),
              ),
            ),
            if (!widget.collapsed)
              Row(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(onPressed: () {}, icon: Icon(Icons.settings)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class UserMenu extends ConsumerWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(connectedUserProvider);
    return Container(
      padding: EdgeInsets.all(10),
      child: user.when<Widget>(
        data:
            (data) => Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(user: data, size: 64),
                Text(data.displayName),
                Text("Online"),
                ElevatedButton(
                  onPressed: () {
                    SessionManager.removeUser(data.id.toString());
                    Navigator.of(context).pushReplacementNamed("/login");
                  },
                  child: Text("Logout"),
                ),
              ],
            ),
        error: (err, stack) => Text(err.toString()),
        loading: () => CircularProgressIndicator(),
      ),
    );
  }
}

class ResizableSidebar extends StatefulWidget {
  final Widget child;
  final double initialWidth;
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
    this.initialWidth = 320,
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
    width = widget.initialWidth;
    isCollapsed = widget.collapsed;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.transparent,
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

class GuildList extends ConsumerWidget {
  const GuildList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guilds = ref.watch(guildsProvider);
    final selectedGuild = ref.watch(selectedGuildProvider);
    final selectedGuildNotifier = ref.read(selectedGuildProvider.notifier);

    final screenPadding = MediaQuery.of(context).padding;

    return Container(
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
                    onTap:
                        () =>
                            ref.read(selectedGuildProvider.notifier).state =
                                null,
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
              onTap: () => selectedGuildNotifier.state = guild,
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
        key: PageStorageKey("Category $id"),
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
