import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nebulon/models/message.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/helpers/cdn_image.dart';
import 'package:flutter_thumbhash/flutter_thumbhash.dart';
import 'package:intl/intl.dart';

class MessageWidget extends StatefulWidget {
  final MessageModel message;
  final bool showHeader;

  const MessageWidget({
    super.key,
    required this.message,
    this.showHeader = true,
  });

  @override
  State<MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: EdgeInsets.only(top: widget.showHeader ? 16 : 0),
      child: InkWell(
        onTap: () {},
        canRequestFocus: false,
        onHover: (state) => setState(() => _isHovered = state),
        focusColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.only(top: 2, bottom: 2, right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.showHeader
                  ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: UserAvatar(user: widget.message.author),
                  )
                  : SizedBox(
                    width: 64,
                    child: Visibility(
                      visible: _isHovered,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat(
                                "h:mm a",
                              ).format(widget.message.timestamp),
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.clip,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Visibility(
                      visible: widget.showHeader,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            widget.message.author.displayName,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            DateFormat(
                              "M/d/yy, h:mm a",
                            ).format(widget.message.timestamp),
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!(widget.message.attachments.isNotEmpty &&
                        widget.message.content.isEmpty))
                      SelectableText(
                        widget.message.content,
                        focusNode: FocusNode(canRequestFocus: false),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              widget.message.hasError
                                  ? Theme.of(context).colorScheme.error
                                  : widget.message.isPending
                                  ? Theme.of(context).hintColor
                                  : null,
                        ),
                      ),
                    if (widget.message.editedTimestamp != null)
                      Tooltip(
                        message: DateFormat("yyyy/MM/dd, hh:mm:ss a").format(
                          widget.message.editedTimestamp ?? DateTime.now(),
                        ),
                        child: Text(
                          "(edited)",
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (widget.message.attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: MessageAttachments(
                          attachments: widget.message.attachments,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageAttachments extends StatelessWidget {
  final List attachments;
  const MessageAttachments({super.key, required this.attachments});

  @override
  Widget build(BuildContext context) {
    // TODO: implement a proper grid layout
    return LayoutBuilder(
      builder: (layoutContext, constraints) {
        final double maxWidth = min(512, constraints.maxWidth - 16);
        const double maxHeight = 360;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: max(maxWidth, 16),
            maxHeight: max(maxHeight, 16),
          ),
          child: Flex(
            direction: Axis.horizontal,
            spacing: 8,
            children:
                attachments.map((a) {
                  final bool isImage = a["content_type"]?.startsWith("image");

                  double finalWidth = maxWidth;
                  double finalHeight = maxHeight;

                  if (isImage) {
                    final double imageWidth = a["width"].toDouble();
                    final double imageHeight = a["height"].toDouble();

                    double scale = min(
                      min(maxWidth / imageWidth, maxHeight / imageHeight),
                      1,
                    );

                    finalWidth = imageWidth * scale;
                    finalHeight = imageHeight * scale;
                  }
                  return Flexible(
                    child:
                        isImage
                            ? FadeInImage(
                              placeholder:
                                  ThumbHash.fromBase64(
                                    a["placeholder"],
                                  ).toImage(),
                              image: NetworkImage(a["url"]),
                              fit: BoxFit.cover,
                              width: finalWidth,
                              height: finalHeight,
                              fadeInDuration: const Duration(milliseconds: 250),
                              fadeOutDuration: const Duration(milliseconds: 1),
                              fadeInCurve: Curves.ease,
                              fadeOutCurve: Curves.linear,
                            )
                            : Text("[${a["filename"]}]"),
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}

class UserAvatar extends StatelessWidget {
  final UserModel user;
  final double size;
  const UserAvatar({super.key, required this.user, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Colors.transparent,
      foregroundImage: cdnImage(
        context,
        "avatars/${user.id}/${user.avatarHash}.png",
        size: size,
      ),
      radius: size / 2,
    );
  }
}
