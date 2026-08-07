import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:nebulon/models/base.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/providers/providers.dart';

class MentionWidget extends StatelessWidget{
  const MentionWidget({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: child,
    );
  }
}

/// Parses user mentions eg: <@1234567890>
class UserMentionSyntax extends md.InlineSyntax {
  UserMentionSyntax() : super(r'<@(\d+)>');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final rawContent = match[1] ?? "";

    final element = md.Element.text('userMention', rawContent);
    parser.addNode(element);
    return true;
  }
}

class UserMentionBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    final snowflake = Snowflake(element.textContent);

    return Consumer(builder: (context, ref, child) {
      final apiService = ref.read(apiServiceProvider).requireValue;
      final Future userFuture = UserModel.getById(snowflake, apiService);

      return MentionWidget(
        child: FutureBuilder(
          future: userFuture,
          builder: (context, snapshot) => Text(
            snapshot.hasData ? "@${snapshot.data.displayName}" : "@unknown user",
            style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
          )
        ),
      );
    });
  }
}

/// Parses spoilers wrapped in double pipes eg: ||text||
class SpoilerSyntax extends md.InlineSyntax {
  SpoilerSyntax() : super(r'\|\|(.*?)\|\|');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('spoiler', match[1] ?? '');
    parser.addNode(element);
    return true;
  }
}

/// Renders a spoiler block that reveals its text when tapped
class SpoilerBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    bool isRevealed = false;
    return StatefulBuilder(
      builder: (context, setState) {

        Text text = Text(
          element.textContent,
          style: TextStyle(
            color: isRevealed ? parentStyle?.color : Colors.transparent,
          ),
        );
        
        return Material(
            color: isRevealed ? Theme.of(context).colorScheme.surfaceContainer : Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
            child: isRevealed ? text : InkWell(
              onTap: () => setState(() => isRevealed = true),
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(4),
              hoverColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: text
            ),
        );
      },
    );
  }
}