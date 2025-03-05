import 'package:nebulon/models/base.dart';
import 'package:nebulon/models/user.dart';

enum MessageType {
  unknown(-1),
  normal(0),
  reply(19);

  final int value;
  const MessageType(this.value);

  static MessageType getByValue(int val) {
    return MessageType.values.firstWhere(
      (t) => t.value == val,
      orElse: () => MessageType.unknown,
    );
  }
}

class MessageModel extends Resource {
  MessageModel({
    required super.id,
    this.type = MessageType.normal,
    required this.content,
    required this.channelId,
    required this.author,
    required this.timestamp,
    this.attachments = const [],
    this.editedTimestamp,
    this.reference,
    this.isPending = false,
    this.hasError = false,
    this.nonce,
  });

  final Snowflake channelId;
  MessageType type = MessageType.normal;
  UserModel author;
  String content;
  DateTime timestamp;
  List<dynamic> attachments;
  DateTime? editedTimestamp;
  MessageModel? reference;
  bool isPending = false; // local state
  bool hasError = false; // same here
  String? nonce; // used to determine which message this was while pending

  @override
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: Snowflake(json["id"]),
      type: MessageType.getByValue(json["type"]),
      content: json["content"],
      channelId: Snowflake(json["channel_id"]),
      author: UserModel.fromJson(json["author"]),
      timestamp: DateTime.parse(json["timestamp"]).toLocal(),
      attachments: json["attachments"],
      editedTimestamp:
          DateTime.tryParse(json["edited_timestamp"] ?? "")?.toLocal(),
      reference:
          (json["referenced_message"] != null
              ? MessageModel.fromJson(json["referenced_message"])
              : null),
      nonce: json["nonce"],
    );
  }
}
