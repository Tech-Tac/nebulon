import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/guild.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

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
        childrenPadding: EdgeInsets.zero,
        dense: true,
        shape: const Border(),
        children: [
          SuperListView.builder(
            key: PageStorageKey("Category list $id"),
            padding: EdgeInsets.zero,
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
        selectedChannelNotifier.state = channel;
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
