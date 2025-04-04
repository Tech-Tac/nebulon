import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/models/base.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/message.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/services/api_service.dart';

class ChannelTextField extends ConsumerStatefulWidget {
  const ChannelTextField({
    super.key,
    required this.channel,
    this.onMessageSubmit,
    this.onMessageSent,
    this.onError,
  });

  final ChannelModel channel;
  final Function(MessageModel)? onMessageSubmit;
  final Function(MessageModel)? onMessageSent;
  final Function(Object)? onError;

  @override
  ConsumerState<ChannelTextField> createState() => _ChannelTextFieldState();
}

class _ChannelTextFieldState extends ConsumerState<ChannelTextField> {
  final TextEditingController _inputController = TextEditingController();
  late final FocusNode _inputFocusNode;

  late final ApiService _api;

  bool _isTyping = false;
  Timer? _resetTypingTimer;

  @override
  void initState() {
    super.initState();

    _api = ref.read(apiServiceProvider).requireValue;

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
  }

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isNotEmpty && text.length < 2000) {
      final nonce = _api.getNextNonce();
      final pendingMessage = MessageModel(
        id: Snowflake.fromDate(DateTime.now()),
        author: ref.read(connectedUserProvider).value!,
        content: text,
        channelId: widget.channel.id,
        timestamp: DateTime.now(),
        isPending: true,
        nonce: nonce,
      );
      _inputController.clear();
      widget.onMessageSubmit?.call(pendingMessage);

      try {
        final message = await _api.sendMessage(widget.channel.id, text, nonce);
        widget.onMessageSent?.call(message);
      } catch (error) {
        pendingMessage.hasError = true;
        widget.onError?.call(error);
        if (!mounted) return;
        setState(() {});
        showDialog(
          context: context,
          builder: (context) {
            return Center(
              child: Dialog(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Can't send message.\nError: $error"),
                ),
              ),
            );
          },
        );
      }
    }
  }

  void _typing() {
    if (_isTyping) return;
    _isTyping = true;

    _api.sendTyping(widget.channel.id).catchError((error) {
      log("Error sending typing event: $error");
    });
    _resetTypingTimer?.cancel();
    _resetTypingTimer = Timer(
      const Duration(seconds: 10),
      () => _isTyping = false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenPadding = MediaQuery.paddingOf(context);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
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
                    hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(128),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _resetTypingTimer?.cancel();
    _isTyping = false;
    super.dispose();
  }
}
