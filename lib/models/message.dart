import 'package:nebulon/models/base.dart';
import 'package:nebulon/models/user.dart';

enum MessageType {
  unsupported(-1),
  normal(0),
  reply(19);

  final int value;
  const MessageType(this.value);

  static MessageType getByValue(int val) {
    return MessageType.values.firstWhere(
      (t) => t.value == val,
      orElse: () => MessageType.unsupported,
    );
  }
}

class MessageModel extends Resource {
  MessageType type = MessageType.normal;
  String content;
  final int channelId;
  UserModel author;
  DateTime timestamp;
  List<dynamic> attachments; // smh
  DateTime? editedTimestamp;
  MessageModel? reference;

  MessageModel({
    required super.id,
    this.type = MessageType.normal,
    required this.content,
    required this.channelId,
    required this.author,
    required this.timestamp,
    required this.attachments,
    this.editedTimestamp,
    this.reference,
  });

  @override
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: Snowflake(json["id"]),
      type: MessageType.getByValue(json["type"]),
      content: json["content"],
      channelId: int.parse(json["channel_id"]),
      author: UserModel.fromJson(json["author"]),
      timestamp: DateTime.parse(json["timestamp"]),
      attachments: json["attachments"],
      editedTimestamp: DateTime.tryParse(json["edited_timestamp"] ?? ""),
      reference:
          (json["referenced_message"] != null
              ? MessageModel.fromJson(json["referenced_message"])
              : null),
    );
  }
}
