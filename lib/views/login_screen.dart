import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:nebulon/providers/providers.dart';
import 'package:nebulon/services/session_manager.dart';
import 'package:nebulon/widgets/window/window_controls.dart';
import 'package:window_manager/window_manager.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    windowManager.setTitle("Nebulon | Login");
    super.initState();
  }

  void _login() async {
    final token = _controller.text.trim();
    if (token.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SessionManager.login(token);
        ref.read(apiServiceProvider.notifier).initialize(token);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed("/home");
      } catch (e) {
        log(e.toString());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Invalid token.\nError: $e",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            showCloseIcon: true,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TitleBar(
            title: const Text("Nebulon | Login"),
            icon: const Icon(Icons.login),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 16,
                children: [
                  Text(
                    "PASTE YOUR TOKEN HERE 🔽👇⬇️⤵️⏬ (100% legit definitely not sketchy)",
                    textAlign: TextAlign.center,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: TextField(
                      controller: _controller,
                      onEditingComplete: _login,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: "[your token]",
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _login,
                    label: const Text("Login"),
                    icon:
                        _isLoading
                            ? SizedBox(
                              height: 16,
                              width: 16,
                              child: const CircularProgressIndicator(),
                            )
                            : const Icon(Icons.login),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
