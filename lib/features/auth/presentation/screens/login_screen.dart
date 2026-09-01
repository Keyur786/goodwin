import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goodwin/features/auth/providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Wholesale Pickup',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 32),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {},
                child: const Text('Send OTP'),
              ),
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: () {
                  ref.read(authProvider.notifier).loginAsCustomer();
                  context.go('/home');
                },
                child: const Text('Continue as demo customer'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(authProvider.notifier).loginAsAdmin();
                  context.go('/admin');
                },
                child: const Text('Continue as admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
