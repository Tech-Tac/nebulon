import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/helpers/cdn_image.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/widgets/window/window_controls.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:universal_platform/universal_platform.dart';

class GuildList extends ConsumerWidget {
  const GuildList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guilds = ref.watch(guildsProvider);
    final selectedGuild = ref.watch(selectedGuildProvider);
    final selectedGuildNotifier = ref.read(selectedGuildProvider.notifier);

    final screenPadding = MediaQuery.paddingOf(context);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.only(
          left: screenPadding.left,
          top: screenPadding.top,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (UniversalPlatform.isMacOS)
              SizedBox(width: 60, height: 48, child: WindowControls()),
            Expanded(
              child: SuperListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: guilds.length + 1,
                itemBuilder: (itemContext, index) {
                  if (index == 0) {
                    return Column(
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
                          color: Theme.of(context).dividerColor.withAlpha(64),
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          height: 24,
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
            ),
          ],
        ),
      ),
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
