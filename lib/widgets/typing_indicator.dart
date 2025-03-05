import 'package:flutter/material.dart';
import 'package:nebulon/models/user.dart';

class TypingIndicatorStrip extends StatelessWidget {
  const TypingIndicatorStrip({
    super.key,
    this.height = 18,
    required this.users,
  });

  final double height;
  final List<UserModel> users;

  @override
  Widget build(BuildContext context) {
    final typingTextStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: Theme.of(context).hintColor,
      fontSize: 10,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: Alignment.centerLeft,
      height: height,
      color: Theme.of(context).colorScheme.surface,
      child: RichText(
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        text: TextSpan(
          style: typingTextStyle,
          children: [
            if (users.length <= 5)
              ...List.generate(users.length, (index) {
                final length = users.length;
                final user = users.elementAt(index);
                return TextSpan(
                  children: [
                    TextSpan(
                      text: user.displayName,
                      style: typingTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).hintColor.withAlpha(160),
                      ),
                    ),
                    if (length > 1 && index == length - 2)
                      TextSpan(text: " and ")
                    else if (length > 1 && index != length - 1)
                      TextSpan(text: ", "),
                  ],
                );
              })
            else
              TextSpan(text: "Multiple people"),

            TextSpan(
              text: users.length > 1 ? " are typing..." : " is typing...",
            ),
          ],
        ),
      ),
    );
  }
}
