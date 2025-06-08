import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/helpers/cdn_image.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class DMList extends ConsumerWidget {
  const DMList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(privateChannelsProvider);
    return SuperListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return ListTile(
          title: Text(channel.displayName, overflow: TextOverflow.ellipsis),
          minVerticalPadding: 16,
          minLeadingWidth: 48,
          selected: ref.watch(selectedChannelProvider) == channel,
          selectedTileColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          leading: CircleAvatar(
            backgroundImage:
                channel.iconPath != null
                    ? cdnImage(context, channel.iconPath!, size: 48)
                    : null,
            child:
                channel.recipients?.length == 1 || channel.iconHash != null
                    ? null
                    : Icon(Icons.group_rounded, size: 24),
          ),
          onTap: () {
            ref.read(selectedChannelProvider.notifier).state = channel;
            Scaffold.of(context).closeDrawer();
          },
          dense: true,
          horizontalTitleGap: 8,
        );
      },
    );
  }
}
