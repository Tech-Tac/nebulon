import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static final _pref = SharedPreferencesAsync();

  static Future<void> saveUserSession(String userId, String authToken) async {
    await _pref.setStringList("saved_users", <String>[
      ...await getSavedUsers(),
      userId,
    ]);
    await FlutterSecureStorage().write(key: userId, value: authToken);
  }

  static Future<Set<String>> getSavedUsers() async =>
      Set.from(await _pref.getStringList("saved_users") ?? []);

  static Future<String?> getUserSession(String userId) async {
    return await FlutterSecureStorage().read(key: userId.toString());
  }

  static Future<void> removeUser(String userId) async {
    await FlutterSecureStorage().delete(key: userId);
    final savedUsers = await getSavedUsers();
    await _pref.setStringList("saved_users", <String>[
      ...savedUsers..remove(userId),
    ]);
    if (await getLastUser() == userId) {
      await _pref.remove("last_user");
    }
  }

  static Future<void> switchUser(String userId) async {
    await _pref.setString("last_user", userId);
  }

  static Future<String?> getLastUser() async {
    final lastUser = await _pref.getString("last_user");
    return lastUser;
  }

  static Future<UserModel> checkToken(String token) async {
    Map<String, dynamic> data;
    try {
      final response = await Dio(
        DiscordAPIOptions,
      ).get("/users/@me", options: Options(headers: {"Authorization": token}));
      data = response.data;
    } catch (e) {
      throw Exception("Invalid token");
    }
    final UserModel user = UserModel.fromJson(data);
    return user;
  }

  static Future<UserModel> login(String token, {Ref? ref}) async {
    final UserModel user = await checkToken(token);
    await saveUserSession(user.id.toString(), token);
    await switchUser(user.id.toString());
    if (ref != null) {
      ref.read(apiServiceProvider.notifier).initialize(token);
    }
    return user;
  }

  static Future<void> clearAll() async {
    await FlutterSecureStorage().deleteAll();
    await _pref.clear(allowList: {"saved_users", "last_user"});
  }
}
