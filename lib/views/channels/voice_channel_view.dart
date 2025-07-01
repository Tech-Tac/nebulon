import 'package:flutter/material.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/views/channels/text_channel_view.dart';

class VoiceChannelView extends StatelessWidget {
  const VoiceChannelView({super.key, required this.channel});

  final ChannelModel channel;

  @override
  Widget build(BuildContext context) {
    final Color hintColor = Theme.of(context).hintColor;

    return Scaffold(
      endDrawer: Drawer(width: 512, child: TextChannelView(channel: channel)),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 16,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 16,
            children: [
              Icon(Icons.mic_none_rounded, size: 32, color: hintColor),
              Text(
                channel.displayName,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: hintColor),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 16,
            children: [
              Tooltip(
                message: "Joining voice is not yet supported.",
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.mic_none_rounded),
                  label: const Text("Join Voice"),
                ),
              ),
              const OpenChatButton(),
            ],
          ),
        ],
      ),
    );
  }
}

class OpenChatButton extends StatelessWidget {
  const OpenChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => Scaffold.of(context).openEndDrawer(),
      icon: const Icon(Icons.chat_bubble_outline_rounded),
      label: const Text("Open Chat"),
    );
  }
}
