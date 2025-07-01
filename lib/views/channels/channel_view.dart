import 'package:flutter/material.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/views/channels/text_channel_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/views/channels/voice_channel_view.dart';

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
        : const NoChannel();
  }
}

class NoChannel extends StatelessWidget {
  const NoChannel({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 16,

        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey),

          const Text(
            "Select a channel to start chatting.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class ChannelView extends StatelessWidget {
  final ChannelModel channel;
  const ChannelView({super.key, required this.channel});

  Widget? _getChannelView(ChannelModel channel) {
    if (channel.type.isText) {
      return TextChannelView(key: ValueKey(channel.id), channel: channel);
    } else if (channel.type.isVoice) {
      return VoiceChannelView(key: ValueKey(channel.id), channel: channel);
    }
    return null; // Unsupported channel type
  }

  @override
  Widget build(BuildContext context) {
    final Widget? channelView = _getChannelView(channel);

    return channelView ??
        Center(
          child: Text(
            "Viewing this channel type is not yet supported.",
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        );
  }
}
