import 'package:nebulon/models/base.dart';
import 'package:nebulon/services/api_service.dart';

class UserModel extends CacheableResource {
  UserModel({
    required super.id,
    required this.username,
    this.globalName,
    this.avatarHash,
  }) {
    _cache.getOrCreate(this);
  }
  String username;
  String? globalName;
  String? avatarHash;

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
      globalName: json["global_name"],
      avatarHash: json["avatar"],
    );
  }

  @override
  void merge(covariant CacheableResource other) {
    if (other is! UserModel) return;

    // all of these fields are not nullable, i dont need the ??
    username = other.username;
    globalName = other.globalName;
    avatarHash = other.avatarHash;
  }

  static Future<UserModel> getById(dynamic id) async {
    return _cache.getById(Snowflake(id)) ?? await ApiService().getUser(id);
  }
}
