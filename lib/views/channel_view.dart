import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/message.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/services/api_service.dart';
import 'package:nebulon/widgets/message_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:scroll_animator/scroll_animator.dart';

import 'package:intl/intl.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class MainChannelView extends ConsumerWidget {
  const MainChannelView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChannel = ref.watch(selectedChannelProvider);

    return selectedChannel != null
        ? ChannelView(channel: selectedChannel)
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

class TextChannelView extends ConsumerStatefulWidget {
  final ChannelModel channel;

  const TextChannelView({super.key, required this.channel});

  @override
  ConsumerState<TextChannelView> createState() => _TextChannelViewState();
}

class _TextChannelViewState extends ConsumerState<TextChannelView> {
  final TextEditingController _inputController = TextEditingController();
  late final FocusNode _inputFocusNode;
  final ScrollController _scrollController = ScrollController();
  // final ScrollController _scrollController =
  //     AnimatedScrollController(animationFactory: const ChromiumEaseInOut());

  late ApiService _api;
  late final StreamSubscription _typingStreamSubscription;
  late final StreamSubscription _messageStreamSubscription;

  @override
  void initState() {
    super.initState();

    ref
        .read(apiServiceProvider)
        .when(
          data: (apiService) => _api = apiService,
          loading: () => throw "API service not initialized",
          error: (err, stack) => throw err,
        );

    _inputFocusNode = FocusNode(
      onKeyEvent: (FocusNode node, KeyEvent evt) {
        if (!HardwareKeyboard.instance.isShiftPressed &&
            (evt.logicalKey == LogicalKeyboardKey.enter ||
                evt.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          if (evt is KeyDownEvent) _sendMessage();

          return KeyEventResult.handled;
        } else {
          return KeyEventResult.ignored;
        }
      },
    );
    _scrollController.addListener(_onScroll);
    _typingStreamSubscription = _api.channelTypingStream.listen(_onTypingStart);
    _messageStreamSubscription = _api.messageEventStream.listen(
      _onMessageEvent,
    );
    _fetchMessages();
  }

  void onChannelSwitch() {
    _resetTypingTimer?.cancel();
    _isTyping = false;
    setState(() => _typingUsers.clear());
    _inputController.clear();
    _inputFocusNode.requestFocus();
    _fetchMessages();
  }

  @override
  void didUpdateWidget(covariant TextChannelView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.channel != widget.channel) {
      onChannelSwitch();
    }
  }

  final Map<UserModel, Timer> _typingUsers = {};

  void _onTypingStart(ChannelTypingEvent event) {
    if (event.channelId != widget.channel.id) return;

    UserModel.getById(event.userId).then((user) {
      setState(() {
        _typingUsers[user]?.cancel();

        _typingUsers[user] = Timer(const Duration(seconds: 5), () {
          setState(() {
            _typingUsers.remove(user);
          });
        });
      });
    });
  }

  void _onMessageEvent(MessageEvent event) {
    if (event.channelId != widget.channel.id) return;
    setState(() {
      if (event.type == MessageEventType.create &&
          _typingUsers.containsKey(event.message!.author)) {
        _typingUsers[event.message!.author]!.cancel();
        _typingUsers.remove(event.message!.author);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 32 &&
        !(widget.channel.isLoading || widget.channel.fullyLoaded)) {
      log("Reached top and fetching more messages");
      _fetchMessages();
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isNotEmpty && text.length < 2000) {
      try {
        _api.sendMessage(widget.channel.id, text);
      } catch (exception) {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: Center(
                child: Text("Can't send message.\nError: $exception"),
              ),
            );
          },
        );
      }
      _inputController.clear();
    }
  }

  bool _isTyping = false;
  Timer? _resetTypingTimer;
  void _typing() {
    if (_isTyping) return;
    _isTyping = true;
    _api.sendTyping(widget.channel.id);
    _resetTypingTimer = Timer(
      const Duration(seconds: 10),
      () => _isTyping = false,
    );
  }

  List<MessageModel> get messages {
    widget.channel.messages ??= [];
    return widget.channel.messages!;
  }

  bool _hasError = false;

  Future<List<MessageModel>> _fetchMessages({int count = 50}) async {
    // the user may navigate to a different channel before the messages load,
    // so we store the current channel to put the messages in when data arrives
    // regardless of the then selected channel.

    final channel = widget.channel;

    if (channel.fullyLoaded || channel.isLoading) return [];

    setState(() {
      _hasError = false;
    });

    List<MessageModel> data = [];

    try {
      if (mounted) setState(() => channel.isLoading = true);
      data = await channel.fetchMessages(count: count) ?? [];
    } catch (error) {
      log(error.toString());
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => channel.isLoading = false);
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    final screenPadding = MediaQuery.of(context).padding;
    return Column(
      children: [
        Expanded(
          child: SuperListView.builder(
            key: PageStorageKey(widget.channel.id),
            reverse: true,
            padding: const EdgeInsets.only(bottom: 16),
            controller: _scrollController,
            itemCount:
                messages.length +
                (_hasError ||
                        widget.channel.isLoading ||
                        widget.channel.fullyLoaded
                    ? 1
                    : 0),
            itemBuilder: (listContext, index) {
              if (index == (messages.length)) {
                if (_hasError) {
                  return Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: Column(
                        spacing: 8,
                        children: [
                          Text("An error occurred while loading messages."),
                          ElevatedButton.icon(
                            onPressed: _fetchMessages,
                            label: Text("Retry"),
                            icon: Icon(Icons.replay),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (widget.channel.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (widget.channel.fullyLoaded) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: Text("This is the beginning of this channel"),
                    ),
                  );
                }
              }
              final MessageModel message = messages[index];
              final MessageModel? prevMessage = widget.channel.messages
                  ?.elementAtOrNull(index + 1);

              final bool showDayDivider =
                  message.timestamp.day != prevMessage?.timestamp.day;

              final bool showMessageHeader =
                  prevMessage == null ||
                  message.author.id != prevMessage.author.id ||
                  message.timestamp
                          .difference(prevMessage.timestamp)
                          .inSeconds >
                      500 ||
                  message.type != MessageType.normal ||
                  showDayDivider;

              final MessageWidget messageWidget = MessageWidget(
                key: ValueKey(message.id),
                message: message,
                showHeader: showMessageHeader,
              );

              if (showDayDivider) {
                return Column(
                  children: [
                    DayDivider(date: message.timestamp),
                    messageWidget,
                  ],
                );
              } else {
                return messageWidget;
              }
            },
          ),
        ),
        Visibility(
          visible: _typingUsers.isNotEmpty,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ..._typingUsers.keys.map((user) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: 6.0,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.transparent,
                        foregroundImage: NetworkImage(
                          "https://cdn.discordapp.com/avatars/${user.id}/${user.avatarHash}.png?size=16",
                        ),
                        radius: 8,
                      ),
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  );
                }),
                Text(
                  _typingUsers.length > 1 ? " are typing..." : " is typing...",
                ),
              ],
            ),
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          padding: EdgeInsets.only(
            bottom: screenPadding.bottom,
            right: screenPadding.right,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 56),
                  child: TextField(
                    focusNode: _inputFocusNode,
                    controller: _inputController,
                    inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                    textInputAction: TextInputAction.newline,
                    onChanged: (value) => _typing(),
                    autofocus: true,
                    maxLines: 10,
                    minLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: "Message #${widget.channel.displayName}",
                      hintStyle: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(128),
                      ),
                      contentPadding: const EdgeInsets.all(13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
                padding: const EdgeInsets.all(12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _resetTypingTimer?.cancel();
    _typingStreamSubscription.cancel();
    _messageStreamSubscription.cancel();
    super.dispose();
  }
}

class DayDivider extends StatelessWidget {
  final DateTime date;
  const DayDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 12, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              DateFormat("MMMM d, yyyy").format(date),
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 10,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
