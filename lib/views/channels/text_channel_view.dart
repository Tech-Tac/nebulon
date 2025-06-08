import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/message.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/services/api_service.dart';
import 'package:nebulon/widgets/channel_text_field.dart';
import 'package:nebulon/widgets/message_widget.dart';
import 'package:nebulon/widgets/typing_indicator.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:scroll_animator/scroll_animator.dart';

class TextChannelView extends ConsumerStatefulWidget {
  final ChannelModel channel;

  const TextChannelView({super.key, required this.channel});

  @override
  ConsumerState<TextChannelView> createState() => _TextChannelViewState();
}

class _TextChannelViewState extends ConsumerState<TextChannelView> {
  // final ScrollController _scrollController = ScrollController();
  final ScrollController _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );

  late ApiService _api;
  late final StreamSubscription _typingStreamSubscription;
  late final StreamSubscription _messageStreamSubscription;

  @override
  void initState() {
    super.initState();

    _api = ref.read(apiServiceProvider).requireValue;

    _scrollController.addListener(_onScroll);
    _typingStreamSubscription = _api.channelTypingStream.listen(_onTypingEvent);
    _messageStreamSubscription = _api.messageEventStream.listen(
      _onMessageEvent,
    );
    _fetchMessages();
  }

  void onChannelSwitch() {
    setState(() => _typingUsers.clear());
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

  void _onMessageEvent(MessageEvent event) {
    if (event.channelId != widget.channel.id) return;
    if (event.type == MessageEventType.create) {
      if (_typingUsers.containsKey(event.message!.author)) {
        _typingUsers[event.message!.author]!.cancel();
        _typingUsers.remove(event.message!.author);
      } else if (event.message!.author.id ==
              ref.read(connectedUserProvider)?.id &&
          _pendingMessages.isNotEmpty) {
        if (_pendingMessages.any(
              (message) => message.nonce == event.message!.nonce,
            ) &&
            event.message!.nonce != null) {
          _pendingMessages.removeWhere(
            (message) => message.nonce == event.message!.nonce,
          );
        } else {
          // TODO: add a proper fallback
          // _pendingMessages.removeLast();
        }
      }
    }
    setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 32 &&
        !(widget.channel.isLoading || widget.channel.fullyLoaded)) {
      log("Reached top and fetching more messages");
      _fetchMessages();
    }
  }

  final _pendingMessages = <MessageModel>[];

  void _onTypingEvent(ChannelTypingEvent event) async {
    if (event.channelId != widget.channel.id ||
        event.userId == ref.read(connectedUserProvider)?.id) {
      return;
    }

    final user = await UserModel.getById(event.userId);
    _typingUsers[user]?.cancel();
    if (!mounted) return;
    setState(() {
      _typingUsers[user] = Timer(const Duration(seconds: 10), () {
        _typingUsers.remove(user);
        if (!mounted) return;
        setState(() {});
      });
    });
  }

  List<MessageModel> get messages {
    widget.channel.messages ??= [];
    return [..._pendingMessages, ...widget.channel.messages!];
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
      channel.isLoading = true;
    });

    List<MessageModel> data = [];

    try {
      data = await channel.fetchMessages(count: count) ?? [];
    } catch (error) {
      log(error.toString());
      if (mounted) setState(() => _hasError = true);
    } finally {
      channel.isLoading = false;
      if (mounted) setState(() {});
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    final double typingUsersStripHeight = 18;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              SuperListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: EdgeInsets.only(bottom: typingUsersStripHeight),
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
                  final MessageModel? prevMessage = messages.elementAtOrNull(
                    index + 1,
                  );

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
              Positioned(
                bottom: 0,
                left: 0,
                right: 12, // for the scrollbar
                child: Visibility(
                  visible: _typingUsers.isNotEmpty,
                  child: TypingIndicatorStrip(
                    height: typingUsersStripHeight,
                    users: _typingUsers.keys.toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        ChannelTextField(
          channel: widget.channel,
          onMessageSubmit: (message) {
            setState(() => _pendingMessages.insert(0, message));
          },
          onError: (_) => setState(() {}),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();

    for (var timer in _typingUsers.values) {
      timer.cancel();
    }
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
