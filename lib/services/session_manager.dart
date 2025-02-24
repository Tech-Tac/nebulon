import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nebulon/models/base.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static Future<void> saveUserSession(
    Snowflake userId,
    String authToken,
  ) async {
    await SharedPreferencesAsync().setStringList("saved_users", <String>[
      ...await getSavedUsers(),
      userId.toString(),
    ]);
    await FlutterSecureStorage().write(
      key: userId.toString(),
      value: authToken,
    );
  }

  static Future<Set<String>> getSavedUsers() async => Set.from(
    await SharedPreferencesAsync().getStringList("saved_users") ?? [],
  );

  static Future<String?> getUserSession(Snowflake userId) async {
    return await FlutterSecureStorage().read(key: userId.toString());
  }

  static Future<void> removeUser(Snowflake userId) async {
    await SharedPreferencesAsync().setStringList("saved_users", <String>[
      ...await getSavedUsers()
        ..remove(userId.toString()),
    ]);
    await FlutterSecureStorage().delete(key: userId.toString());
  }

  static Future<void> switchUser(Snowflake userId) async {
    await SharedPreferencesAsync().setString("last_user", userId.toString());
  }

  static Future<Snowflake?> getLastUser() async {
    final lastUser = await SharedPreferencesAsync().getString("last_user");
    return lastUser != null ? Snowflake(lastUser) : null;
  }

  static Future<UserModel> login(String token, {Ref? ref}) async {
    Map<String, dynamic> response;
    try {
      response =
          (await Dio(DiscordAPIOptions).get(
            "/users/@me",
            options: Options(headers: {"Authorization": token}),
          )).data;
    } catch (e) {
      throw Exception("Invalid token");
    }
    final UserModel user = UserModel.fromJson(response);
    await saveUserSession(user.id, token);
    await switchUser(user.id);
    if (ref != null) {
      ref.read(apiServiceProvider.notifier).initialize(token);
    }
    return user;
  }
}
