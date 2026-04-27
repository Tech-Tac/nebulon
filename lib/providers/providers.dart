import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/guild.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/services/api_service.dart';

// api service

class ApiServiceNotifier extends AsyncNotifier<ApiService> {
  @override
  Future<ApiService> build() async {
    return Future.value(Completer<ApiService>().future); // stays loading
  }

  Future<void> initialize(String token) async {
    state = const AsyncValue.loading();
    try {
      final service = ApiService(ref: ref, token: token);
      
      service.currentUserStream.listen((user) {
        ref.read(connectedUserProvider.notifier).setUser(user);
      });
      state = AsyncValue.data(service);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final apiServiceProvider =
    AsyncNotifierProvider<ApiServiceNotifier, ApiService>(
  ApiServiceNotifier.new,
);

// event stream

final messageEventStreamProvider = StreamProvider<MessageEvent>((ref) {
  return ref.watch(apiServiceProvider).when(
        data: (api) => api.messageEventStream,
        loading: () => const Stream.empty(),
        error: (e, st) => Stream.error(e, st),
      );
});

// connected user

class ConnectedUserNotifier extends Notifier<UserModel?> {
  @override
  UserModel? build() => null;

  void setUser(UserModel user) => state = user;
  void clear() => state = null;
}

final connectedUserProvider =
    NotifierProvider<ConnectedUserNotifier, UserModel?>(
  ConnectedUserNotifier.new,
);

// private channels

class PrivateChannelsNotifier extends Notifier<List<ChannelModel>> {
  @override
  List<ChannelModel> build() => [];

  void setAll(List<ChannelModel> channels) => state = channels;
  void add(ChannelModel channel) => state = [...state, channel];
  void remove(ChannelModel channel) =>
      state = state.where((c) => c.id != channel.id).toList();
}

final privateChannelsProvider =
    NotifierProvider<PrivateChannelsNotifier, List<ChannelModel>>(
  PrivateChannelsNotifier.new,
);

// guilds

class GuildsNotifier extends Notifier<List<GuildModel>> {
  @override
  List<GuildModel> build() => [];

  void setAll(List<GuildModel> guilds) => state = guilds;
  void add(GuildModel guild) => state = [...state, guild];
  void remove(GuildModel guild) =>
      state = state.where((g) => g.id != guild.id).toList();
}

final guildsProvider = NotifierProvider<GuildsNotifier, List<GuildModel>>(
  GuildsNotifier.new,
);

// selected guild

class SelectedGuildNotifier extends Notifier<GuildModel?> {
  @override
  GuildModel? build() => null;

  void select(GuildModel? guild) {
    state = guild;
    if (guild != null) {
      // Side effect: subscribe to gateway events for this guild
      ref.read(apiServiceProvider).value?.subscribeToGuild(guild.id);
    }
  }

  void clear() => state = null;
}

final selectedGuildProvider =
    NotifierProvider<SelectedGuildNotifier, GuildModel?>(
  SelectedGuildNotifier.new,
);

// selected channel

class SelectedChannelNotifier extends Notifier<ChannelModel?> {
  @override
  ChannelModel? build() => null;

  void select(ChannelModel? channel) => state = channel;
  void clear() => state = null;
}

final selectedChannelProvider =
    NotifierProvider<SelectedChannelNotifier, ChannelModel?>(
  SelectedChannelNotifier.new,
);

// ui state

class HasDrawerNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
  void toggle() => state = !state;
}

final hasDrawerProvider = NotifierProvider<HasDrawerNotifier, bool>(
  HasDrawerNotifier.new,
);

class SidebarWidthNotifier extends Notifier<double> {
  @override
  double build() => 320;

  void set(double width) => state = width;
}

final sidebarWidthProvider = NotifierProvider<SidebarWidthNotifier, double>(
  SidebarWidthNotifier.new,
);

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
  void toggle() => state = !state;
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
  SidebarCollapsedNotifier.new,
);

// derived state

final menuCollapsedProvider = Provider.autoDispose(
  (ref) =>
      !ref.watch(hasDrawerProvider) && ref.watch(sidebarCollapsedProvider),
);