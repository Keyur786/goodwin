import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goodwin/features/auth/providers/auth_provider.dart';
import 'package:goodwin/models/user_model.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      final user = ref.read(authProvider);
      if (user == null) {
        context.go('/login');
        return;
      }

      final targetPath = user.role == UserRole.superAdmin ? '/admin' : '/home';
      context.go(targetPath);
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 220,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront, size: 120),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Loading your warehouse marketplace...'),
          ],
        ),
      ),
    );
  }
}
