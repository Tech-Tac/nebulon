import 'package:dio/dio.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static final _pref = SharedPreferencesAsync();

  // is this safe?
  static String? currentSessionToken;

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

  static Future<UserModel> getUserByToken(String token) async {
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

  static Future<UserModel?> getUserByTokenOrNull(String token) async {
    try {
      return await getUserByToken(token);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> checkToken(String token) async {
    try {
      await getUserByToken(token);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<UserModel> login(String token) async {
    final UserModel user = await getUserByToken(token);

    await saveUserSession(user.id.toString(), token);
    await switchUser(user.id.toString());
    currentSessionToken = token;

    return user;
  }

  static Future logout() async {
    final lastUser = await getLastUser();
    if (lastUser != null) {
      await removeUser(lastUser);
    }
    currentSessionToken = null;
  }

  static Future loginLastSession() async {
    final lastUser = await getLastUser();
    if (lastUser == null) {
      throw Exception("No last user found");
    }
    final authToken = await getUserSession(lastUser);
    if (authToken == null) {
      throw Exception("No auth token found");
    }

    await login(authToken);
    return authToken;
  }

  static Future<void> clearAll() async {
    await FlutterSecureStorage().deleteAll();
    await _pref.clear(allowList: {"saved_users", "last_user"});
  }
}
