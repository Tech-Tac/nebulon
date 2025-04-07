import 'package:flutter/material.dart';
import 'package:nebulon/widgets/window_controls.dart';
import 'package:nebulon/widgets/window_move_area.dart';
import 'package:universal_platform/universal_platform.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMac = UniversalPlatform.isMacOS;
    return WindowMoveArea(
      child: Scaffold(
        body: Stack(
          children: [
            Center(child: CircularProgressIndicator()),
            if (UniversalPlatform.isDesktop)
              Positioned(
                right: isMac ? null : 0,
                left: isMac ? 2 : null,
                top: 0,
                height: 48,
                width: isMac ? 60 : null,
                child: WindowControls(),
              ),
          ],
        ),
      ),
    );
  }
}
