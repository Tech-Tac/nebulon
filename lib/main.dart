import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/services/session_manager.dart';
import 'package:nebulon/views/home_screen.dart';
import 'package:nebulon/views/login_screen.dart';
import 'package:nebulon/views/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  if (UniversalPlatform.isDesktop) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      title: "Nebulon",
      center: true,
      minimumSize: Size(360, 360),
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Nebulon', // does this even do anything?
      // TODO: make theme customizable by the user
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigoAccent,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigoAccent,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => VirtualWindowFrameInit()(context, child),

      // im not even using these
      routes: {
        "/home": (context) => const HomeScreen(),
        "/login": (context) => const LoginScreen(),
      },
      home: FutureBuilder(
        // this is even barely a future, more like next millisecond smh
        future: SessionManager.getLastUser(),
        builder: (context, snapshot) {
          // this is a mess
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return const SplashScreen();
            case ConnectionState.done:
              if (snapshot.hasData && snapshot.data != null) {
                // re-initializing the service on rebuild causes connections to reload,
                // so we make sure it is not initialized yet (loading is the default state).
                ref
                    .read(apiServiceProvider)
                    .when(
                      data: (_) {},
                      error: (err, _) => log(err.toString()),
                      loading: () {
                        SessionManager.getUserSession((snapshot.data)!).then((
                          token,
                        ) {
                          // actual login vvv
                          ref
                              .read(apiServiceProvider.notifier)
                              .initialize(token!);
                        });
                      },
                    );
                return const HomeScreen();
              } else {
                return const LoginScreen();
              }
            default:
              return const LoginScreen();
          }
        },
      ),
    );
  }
}
