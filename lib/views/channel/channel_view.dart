import 'package:flutter/material.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/views/channel/text_channel_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainChannelView extends ConsumerWidget {
  const MainChannelView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChannel = ref.watch(selectedChannelProvider);

    return selectedChannel != null
        ? ChannelView(
          key: ValueKey(selectedChannel.id),
          channel: selectedChannel,
        )
        : const Center(child: Text("Select a channel to start chatting"));
  }
}

class ChannelView extends StatelessWidget {
  final ChannelModel channel;
  const ChannelView({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return channel.type.isText
        ? TextChannelView(channel: channel)
        : switch (channel.type) {
          _ => Center(child: Text("Can't view this channel type yet.")),
        };
  }
}
