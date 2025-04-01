import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/services/session_manager.dart';
import 'package:nebulon/widgets/message_widget.dart';

class UserMenuCard extends ConsumerStatefulWidget {
  const UserMenuCard({super.key, required this.collapsed});

  final bool collapsed;

  @override
  ConsumerState<UserMenuCard> createState() => _UserMenuCardState();
}

class _UserMenuCardState extends ConsumerState<UserMenuCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 150),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  void _showPopup() {
    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              // Dismiss popup when tapping anywhere
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _removePopup(),
                  child: Container(),
                ),
              ),
              // Animated Popup positioned above the button
              Positioned(
                left: offset.dx,
                bottom: MediaQuery.of(context).size.height - offset.dy + 8,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceBright,
                    child: UserMenu(),
                  ),
                ),
              ),
            ],
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward(); // Start fade-in animation
  }

  void _removePopup() async {
    await _animationController.reverse(); // Play fade-out animation
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectedUser = ref.watch(connectedUserProvider);
    final screenPadding = MediaQuery.of(context).padding;
    return Material(
      color: Theme.of(context).colorScheme.surfaceBright,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: screenPadding.bottom,
          left: screenPadding.left,
        ),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 4,
              children: [
                Expanded(
                  child: InkWell(
                    key: _buttonKey,
                    onTap: _showPopup,
                    borderRadius: BorderRadius.circular(8),
                    child: connectedUser.when(
                      data:
                          (user) => Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            child: Row(
                              spacing: 8,
                              children: [
                                UserAvatar(user: user, size: 40),
                                if (!widget.collapsed)
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(user.displayName),
                                      Text(
                                        "Online",
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall!.copyWith(
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                      loading: () {
                        return Center(child: CircularProgressIndicator());
                      },
                      error:
                          (error, stackTrace) =>
                              Center(child: Text("Error loading user")),
                    ),
                  ),
                ),
                if (!widget.collapsed)
                  Row(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(onPressed: () {}, icon: Icon(Icons.settings)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserMenu extends ConsumerWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(connectedUserProvider);
    return Container(
      padding: EdgeInsets.all(10),
      child: user.when<Widget>(
        data:
            (data) => Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(user: data, size: 64),
                Text(data.displayName),
                Text("Online"),
                ElevatedButton(
                  onPressed: () {
                    SessionManager.logout();
                    Navigator.of(context).pushReplacementNamed("/login");
                  },
                  child: Text("Logout"),
                ),
              ],
            ),
        error: (err, stack) => Text(err.toString()),
        loading: () => CircularProgressIndicator(),
      ),
    );
  }
}
