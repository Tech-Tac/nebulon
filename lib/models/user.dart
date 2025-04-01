import 'package:nebulon/models/base.dart';
import 'package:nebulon/services/api_service.dart';

class UserModel extends CacheableResource {
  UserModel({
    required super.id,
    required this.username,
    this.discriminator = "0000",
    this.globalName,
    this.avatarHash,
  }) {
    _cache.getOrCreate(this);
  }
  String username;
  String discriminator;
  String? globalName;
  String? avatarHash;

  String get avatarPath {
    return avatarHash != null
        ? "avatars/$id/$avatarHash.png"
        : (discriminator != "0000"
            ? "embed/avatars/${int.parse(discriminator) % 5}.png"
            : "embed/avatars/${id.value >> 22 % 6}.png");
  }

  String get legacyUsername {
    return "$username#$discriminator";
  }

  String get displayName {
    return globalName ?? username;
  }

  set displayName(String value) {
    globalName = value;
  }

  static final CacheRegistry<UserModel> _cache = CacheRegistry();

  @override
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: Snowflake(json["id"]),
      username: json["username"],
      discriminator: json["discriminator"] ?? "0000",
      globalName: json["global_name"],
      avatarHash: json["avatar"],
    );
  }

  @override
  void merge(covariant CacheableResource other) {
    if (other is! UserModel) return;

    username = other.username;
    globalName = other.globalName;
    avatarHash = other.avatarHash;
  }

  static Future<UserModel> getById(Snowflake id) async {
    return _cache.getById(Snowflake(id)) ?? await ApiService().getUser(id);
  }
}
