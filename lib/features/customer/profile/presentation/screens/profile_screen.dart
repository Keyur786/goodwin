import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: CircleAvatar(child: Icon(LucideIcons.user)),
            title: Text('Riya Traders'),
            subtitle: Text('+91 9876543210'),
          ),
          Divider(),
          ListTile(title: Text('Business profile')),
          ListTile(title: Text('Address')),
          ListTile(title: Text('GST')),
          ListTile(title: Text('Wallet')),
          ListTile(title: Text('Logout')),
        ],
      ),
    );
  }
}
