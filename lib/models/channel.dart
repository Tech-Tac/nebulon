import 'dart:async';

import 'package:nebulon/models/base.dart';
import 'package:nebulon/models/message.dart';
import 'package:flutter/material.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/services/api_service.dart';

enum ChannelType {
  unknown(-1),
  text(0, isText: true),
  dm(1, isText: true, isDM: true),
  voice(2, isVoice: true),
  group(3, isText: true, isDM: true),
  category(4),
  news(5, isText: true),
  newsThread(10, isText: true),
  thread(11, isText: true),
  privateThread(12, isText: true),
  stage(13, isVoice: true),
  forum(15);

  final int value;
  final bool isText; // Text-only channels
  final bool isVoice; // Channels that are primarily for calls
  final bool isDM; // DM text channels, can also host calls
  const ChannelType(
    this.value, {
    this.isText = false,
    this.isVoice = false,
    this.isDM = false,
  });

  static ChannelType getByValue(int val) {
    return ChannelType.values.firstWhere(
      (t) => t.value == val,
      orElse: () => ChannelType.unknown,
    );
  }
}

getChannelSymbol(ChannelType? type) => switch (type) {
  ChannelType.voice => Icons.mic,
  ChannelType.stage => Icons.podcasts,
  ChannelType.news => Icons.campaign_rounded,
  ChannelType.forum => Icons.forum_rounded,
  ChannelType.thread => Icons.chat,
  ChannelType.dm => Icons.person,
  ChannelType.group => Icons.group,
  ChannelType.category => Icons.folder,
  ChannelType.privateThread => Icons.lock,
  ChannelType.newsThread => Icons.article,
  // ChannelType.unknown => Icons.question_mark,
  _ => Icons.tag,
};

class ChannelModel extends CacheableResource {
  ChannelModel({
    required super.id,
    this.guildId,
    this.name,
    this.iconHash,
    required this.type,
    this.recipients,
    this.parentId,
    this.position,
    this.messages,
    this.fullyLoaded = false,
    ApiService? service,
  }) : _service = service {
    _listener ??= _service?.messageEventStream.listen(_onNewMessage);
    _cache.getOrCreate(this);
  }
  final int? guildId;
  String? name;
  String? iconHash;
  int? parentId;
  ChannelModel? get parent => parentId != null ? getById(parentId!) : null;
  int? position = 0;
  ChannelType type = ChannelType.text;
  List<UserModel>? recipients = [];

  final ApiService? _service;
  List<MessageModel>? messages;
  bool fullyLoaded = false;
  bool isLoading = false;

  String get displayName =>
      name ?? recipients?.map((e) => e.displayName).join(", ") ?? "$id";

  String? get iconPath =>
      recipients?.length == 1
          ? recipients!.first.avatarPath
          : iconHash != null
          ? "/channels/$id/icons/$iconHash.png"
          : null;

  StreamSubscription? _listener;

  void _onNewMessage(MessageEvent event) {
    if (event.channelId != id) return;

    if (event.type == MessageEventType.create) {
      messages ??= [];
      messages!.insert(0, event.message!);
    } else if (messages != null &&
        messages!.isNotEmpty &&
        event.messageId >= messages!.last.id) {
      switch (event.type) {
        case MessageEventType.update:
          messages![messages!.indexWhere((m) => m.id == event.messageId)] =
              event.message!;
          break;
        case MessageEventType.delete:
          messages?.removeAt(
            messages!.indexWhere((m) => m.id == event.messageId),
          );
          break;
        default:
          break;
      }
    }
  }

  Future<List<MessageModel>?> fetchMessages({int count = 50}) async {
    final data = await _service?.getMessages(
      channelId: id,
      before: messages?.lastOrNull?.id,
      limit: count,
    );

    messages ??= [];
    if (data?.isNotEmpty ?? false) messages!.addAll(data!);
    if ((data?.length ?? 0) < count) fullyLoaded = true;

    return data;
  }

  static final CacheRegistry<ChannelModel> _cache = CacheRegistry();

  static ChannelModel? getById(int id) => _cache.getById(Snowflake(id));

  factory ChannelModel.fromJson(
    Map<String, dynamic> json, {
    ApiService? service,
  }) {
    return ChannelModel(
      id: Snowflake(json["id"]),
      guildId: int.tryParse(json["guild_id"] ?? ""),
      type: ChannelType.getByValue(json["type"]),
      recipients:
          json["recipients"] != null
              ? (json["recipients"] as List)
                  .map((userJson) => UserModel.fromJson(userJson))
                  .toList()
              : [],
      parentId: int.tryParse(json["parent_id"] ?? ""),
      position: json["position"],
      name: json["name"],
      service: service,
    );
  }

  @override
  void merge(covariant CacheableResource other) {}
}
