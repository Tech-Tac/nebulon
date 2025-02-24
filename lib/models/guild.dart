import 'dart:ui';

import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/services/api_service.dart';

class RoleModel {
  final int id;
  String name;
  String? description;
  Color color;
  String? iconHash;
  int position;
  int permissions;

  RoleModel({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    this.iconHash,
    required this.position,
    required this.permissions,
  });

  static final Map<int, RoleModel> _cache = {};

  static RoleModel? getById(int id) => _cache[id];

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    int id = int.parse(json["id"]);
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    } else {
      final role = RoleModel(
        id: id,
        name: json["name"],
        description: json["description"],
        color: Color(json["color"]),
        iconHash: json["icon"],
        position: json["position"],
        permissions: 0, // TODO: implement permisions
      );
      _cache[id] = role;
      return role;
    }
  }
}

class MemberModel {
  final UserModel user;
  final DateTime joinedDate;
  String? nickname;
  List<RoleModel> roles;

  Color getRoleColor() {
    roles.sort((a, b) => a.position.compareTo(b.position));
    return roles.lastWhere((role) => role.color != Color(0x00000000)).color;
  }

  String getRoleIconHash() {
    roles.sort((a, b) => a.position.compareTo(b.position));
    return roles.lastWhere((role) => role.iconHash != null).iconHash!;
  }

  MemberModel({
    required this.user,
    required this.joinedDate,
    this.nickname,
    required this.roles,
  });

  @override
  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      user: UserModel.fromJson(json["user"]),
      nickname: json["nick"],
      joinedDate: DateTime.fromMillisecondsSinceEpoch(
        int.parse(json["joined_at"]),
      ),
      roles:
          (json["roles"] as List)
              .map((role) => RoleModel.fromJson(role))
              .toList(),
    );
  }
}

class GuildModel {
  final int id;
  String name;
  String? iconHash;
  List<ChannelModel> channels;
  List<RoleModel> roles;

  GuildModel({
    required this.id,
    required this.name,
    this.iconHash,
    required this.channels,
    required this.roles,
  });

  factory GuildModel.fromJson(
    Map<String, dynamic> json, {
    ApiService? service,
  }) {
    return GuildModel(
      id: int.parse(json["id"]),
      name: json["name"],
      iconHash: json["icon"],
      channels:
          (json["channels"] as List)
              .map(
                (channelJson) =>
                    ChannelModel.fromJson(channelJson, service: service),
              )
              .toList(),
      roles:
          (json["roles"] as List)
              .map((role) => RoleModel.fromJson(role))
              .toList(),
    );
  }
}
