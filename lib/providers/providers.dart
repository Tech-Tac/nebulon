import 'dart:async';

import 'package:nebulon/models/channel.dart';
import 'package:nebulon/models/guild.dart';
import 'package:nebulon/models/user.dart';
import 'package:nebulon/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiServiceNotifier extends StateNotifier<AsyncValue<ApiService>> {
  ApiServiceNotifier(this.ref) : super(AsyncValue.loading());

  final Ref ref;

  void initialize(String token) {
    try {
      final service = ApiService(ref: ref, token: token);
      state = AsyncValue.data(service);
      service.currentUserStream.listen((user) {
        ref.read(connectedUserProvider.notifier).state = user;
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final apiServiceProvider =
    StateNotifierProvider<ApiServiceNotifier, AsyncValue<ApiService>>(
      (ref) => ApiServiceNotifier(ref),
    );

final messageEventStreamProvider = StreamProvider<MessageEvent>((ref) {
  return ref
      .watch(apiServiceProvider)
      .when(
        data: (apiService) => apiService.messageEventStream,
        loading: () => const Stream.empty(),
        error: (err, stack) => Stream.error(err, stack),
      );
});

final connectedUserProvider = StateProvider<UserModel?>((_) => null);

final privateChannelsProvider = StateProvider<List<ChannelModel>>((ref) => []);

final guildsProvider = StateProvider<List<GuildModel>>((ref) => []);

class SelectedGuildProvider extends StateNotifier<GuildModel?> {
  SelectedGuildProvider(this.ref) : super(null);

  final Ref ref;

  void set(GuildModel? newGuild) {
    state = newGuild;
    if (newGuild != null) {
      ref.read(apiServiceProvider).valueOrNull?.subscribeToGuild(newGuild.id);
    }
  }
}

final selectedGuildProvider =
    StateNotifierProvider<SelectedGuildProvider, GuildModel?>(
      (ref) => SelectedGuildProvider(ref),
    );

final selectedChannelProvider = StateProvider<ChannelModel?>((ref) => null);

final hasDrawerProvider = StateProvider<bool>((ref) => false);
final sidebarWidthProvider = StateProvider<double>((ref) => 320);
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
final menuCollapsedProvider = Provider.autoDispose(
  (ref) => !ref.watch(hasDrawerProvider) && ref.watch(sidebarCollapsedProvider),
);
