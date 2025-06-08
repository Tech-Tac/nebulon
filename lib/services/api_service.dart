import 'dart:async';

import 'package:dio/dio.dart';
import 'package:nebulon/models/base.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/guild.dart';

import 'package:nebulon/models/message.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/services/gateway_channel.dart';

import 'package:nebulon/services/interceptors/authorization_interceptor.dart';
import 'package:nebulon/services/interceptors/ratelimit_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MessageEventType { create, update, delete }

class MessageEvent {
  final MessageEventType type;
  final Snowflake channelId;
  final Snowflake messageId;
  final MessageModel? message;

  MessageEvent({
    required this.type,
    required this.channelId,
    required this.messageId,
    this.message,
  });
}

class ChannelTypingEvent {
  final Snowflake userId;
  final Snowflake channelId;
  final Snowflake? guildId;
  final DateTime timestamp;

  ChannelTypingEvent({
    required this.userId,
    required this.channelId,
    this.guildId,
    required this.timestamp,
  });
}

// ignore: non_constant_identifier_names
final DiscordAPIOptions = BaseOptions(
  baseUrl: "https://discord.com/api/v10/",
  responseType: ResponseType.json,
  headers: {'Content-Type': 'application/json'},
);

class ApiService {
  // this class is really a mess

  ApiService._internal({required token}) : _token = token {
    _connectGateway();
  }

  static ApiService? _instance;
  late final Ref _ref;

  factory ApiService({String? token, Ref? ref}) {
    assert(
      token == null ? _instance != null : true,
      "Please provide a token to initialize the service.",
    );

    if (token != null) {
      _instance?.dispose();
      _instance = ApiService._internal(token: token);
    }
    if (ref != null) {
      _instance!._ref = ref;
    }

    return _instance!;
  }

  void dispose() {
    _gateway?.dispose();
    _dio.close();
    _messageEventController.close();
    _channelTypingController.close();
    _currentUserStreamController.close();
  }

  final String _token;

  GatewayChannel? _gateway;

  late final Dio _dio = () {
    final dio = Dio(DiscordAPIOptions);
    dio.interceptors.addAll([
      AuthorizationInterceptor(_token),
      RateLimitInterceptor(dio),
    ]);

    return dio;
  }();

  final _messageEventController = StreamController<MessageEvent>.broadcast();
  Stream<MessageEvent> get messageEventStream => _messageEventController.stream;

  final _channelTypingController =
      StreamController<ChannelTypingEvent>.broadcast();
  Stream<ChannelTypingEvent> get channelTypingStream =>
      _channelTypingController.stream;

  final _currentUserStreamController = StreamController<UserModel>.broadcast();
  Stream<UserModel> get currentUserStream =>
      _currentUserStreamController.stream;

  void _connectGateway() async {
    if (_token == "") return;

    _gateway = GatewayChannel(
      (await _dio.get<Map<String, dynamic>>("/gateway")).data!["url"],
      _token,
    );
    _gateway!.listen(_onGatewayEvent);
  }

  void _onGatewayEvent(DispatchEvent event) {
    final data = event.data;
    switch (event.type) {
      case "READY":
        _currentUserStreamController.add(UserModel.fromJson(data["user"]));
        _ref.read(guildsProvider.notifier).state =
            (data["guilds"] as List)
                .map((guild) => GuildModel.fromJson(guild, service: this))
                .toList();
        _ref.read(privateChannelsProvider.notifier).state =
            (data["private_channels"] as List)
                .map((channel) => ChannelModel.fromJson(channel, service: this))
                .toList();
      case "MESSAGE_CREATE":
        _messageEventController.add(
          MessageEvent(
            type: MessageEventType.create,
            messageId: Snowflake(data["id"]),
            channelId: Snowflake(data["channel_id"]),
            message: MessageModel.fromJson(data),
          ),
        );
        break;
      case "MESSAGE_UPDATE":
        _messageEventController.add(
          MessageEvent(
            type: MessageEventType.update,
            messageId: Snowflake(data["id"]),
            channelId: Snowflake(data["channel_id"]),
            message: MessageModel.fromJson(data),
          ),
        );
        break;
      case "MESSAGE_DELETE":
        _messageEventController.add(
          MessageEvent(
            type: MessageEventType.delete,
            messageId: Snowflake(data["id"]),
            channelId: Snowflake(data["channel_id"]),
          ),
        );
        break;
      case "TYPING_START":
        _channelTypingController.add(
          ChannelTypingEvent(
            userId: Snowflake(data["user_id"]),
            channelId: Snowflake(data["channel_id"]),
            timestamp: DateTime.fromMicrosecondsSinceEpoch(data["timestamp"]),
          ),
        );
        break;
    }
  }

  Future<List<MessageModel>> getMessages({
    required Snowflake channelId,
    int? limit = 50,
    Snowflake? before,
  }) async {
    Map<String, dynamic> queryParameters = {};
    if (limit != null) queryParameters["limit"] = limit;
    if (before != null) queryParameters["before"] = before.value;
    final data =
        (await _dio.get(
          "/channels/$channelId/messages",
          queryParameters: queryParameters,
        )).data;
    return (data as List).map((d) => MessageModel.fromJson(d)).toList();
  }

  int _messageCount = 0;

  String getNextNonce() {
    final nonce =
        DateTime.now().millisecondsSinceEpoch.toString() +
        _messageCount.toString();
    _messageCount++;
    return nonce;
  }

  Future<MessageModel> sendMessage(
    Snowflake channelId,
    String content,
    String nonce,
  ) async {
    final response = await _dio.post(
      "/channels/$channelId/messages",
      data: {"content": content, "nonce": nonce},
    );
    final message = MessageModel.fromJson(response.data);
    message.nonce = nonce;
    return message;
  }

  Future<UserModel> getUser(Snowflake id) async {
    return UserModel.fromJson((await _dio.get("/users/$id")).data);
  }

  Future<void> sendTyping(Snowflake channelId) async {
    await _dio.post("/channels/$channelId/typing");
  }

  void subscribeToGuild(
    Snowflake guildId, {
    bool typing = true,
    bool activities = true,
    bool threads = true,
  }) {
    _gateway?.send({
      "op": 14,
      "d": {
        "guild_id": guildId.value,
        "typing": typing,
        "activities": activities,
        "threads": threads,
      },
    });
  }
}
