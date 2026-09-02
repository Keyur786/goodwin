import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:goodwin/core/constants/app_constants.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/features/customer/screens/customer_orders_screen.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/customer_tier_badge.dart';
import 'package:goodwin/shared/widgets/profile_avatar_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DrawerProfileItem extends StatelessWidget {
  const DrawerProfileItem({
    super.key,
    required this.icon,
    required this.label,
    required this.action,
    required this.onSelected,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final ProfileAction action;
  final ValueChanged<ProfileAction> onSelected;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade600 : const Color(0xFF1E293B);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red.shade600 : const Color(0xFF2563EB),
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          LucideIcons.chevronRight,
          size: 14,
          color: Color(0xFF94A3B8),
        ),
        onTap: () {
          Navigator.of(context).pop();
          onSelected(action);
        },
      ),
    );
  }
}


class ProfilePage extends StatefulWidget {
  final AppUser? currentUser;
  final ValueChanged<AppUser>? onUserUpdated;

  const ProfilePage({super.key, this.currentUser, this.onUserUpdated});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late AppUser? _user;
  final _userRepo = FirestoreUserRepository();

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
  }

  Future<void> _changeProfilePhoto() async {
    if (_user == null) return;
    await showProfilePhotoPickerSheet(
      context: context,
      currentPhotoUrl: _user?.photoUrl,
      onPhotoSelected: (newPhotoUrl) async {
        await _userRepo.updateUser(
          userId: _user!.id,
          data: {'photoUrl': newPhotoUrl ?? ''},
        );
        final updated = _user!.copyWith(photoUrl: newPhotoUrl);
        if (mounted) {
          setState(() => _user = updated);
          widget.onUserUpdated?.call(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newPhotoUrl != null
                    ? 'Profile picture updated successfully!'
                    : 'Profile picture removed',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<void> _showEditUsernameDialog() async {
    if (_user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: _user?.username ?? '');
    String? dialogError;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Username'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a unique 6-alphabet username for your wholesale reseller profile.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Username (6 letters)',
                      prefixText: '@',
                      hintText: 'ABCXYZ',
                      errorText: dialogError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final candidate = controller.text
                              .trim()
                              .toUpperCase();
                          if (candidate.length != 6) {
                            setDialogState(() {
                              dialogError =
                                  'Username must be exactly 6 letters.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          final isAvailable = await _userRepo
                              .isUsernameAvailable(
                                candidate,
                                excludeUserId: _user!.id,
                              );

                          if (!isAvailable) {
                            setDialogState(() {
                              isSaving = false;
                              dialogError =
                                  '@$candidate is already taken. Try another.';
                            });
                            return;
                          }

                          await _userRepo.updateUser(
                            userId: _user!.id,
                            data: {
                              'username': candidate,
                              if (_user!.name.startsWith('Reseller '))
                                'name': 'Reseller $candidate',
                            },
                          );

                          final updated = _user!.copyWith(
                            username: candidate,
                            name: _user!.name.startsWith('Reseller ')
                                ? 'Reseller $candidate'
                                : _user!.name,
                          );

                          if (mounted) {
                            setState(() => _user = updated);
                            widget.onUserUpdated?.call(updated);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Username updated to @$candidate',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditProfileDialog() async {
    if (_user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController(text: _user?.name ?? '');
    final shopCtrl = TextEditingController(text: _user?.shopName ?? '');
    final emailCtrl = TextEditingController(text: _user?.email ?? '');
    final addressCtrl = TextEditingController(text: _user?.address ?? '');
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Personal Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: shopCtrl,
                      decoration: const InputDecoration(labelText: 'Shop Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address / Area',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          await _userRepo.updateUser(
                            userId: _user!.id,
                            data: {
                              'name': nameCtrl.text.trim(),
                              'shopName': shopCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'address': addressCtrl.text.trim(),
                            },
                          );

                          final updated = _user!.copyWith(
                            name: nameCtrl.text.trim(),
                            shopName: shopCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            address: addressCtrl.text.trim(),
                          );

                          if (mounted) {
                            setState(() => _user = updated);
                            widget.onUserUpdated?.call(updated);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = _user?.username ?? 'GWUSER';
    final name = _user?.name.isNotEmpty == true
        ? _user!.name
        : 'Wholesale Reseller';
    final phone = _user?.phone.isNotEmpty == true
        ? _user!.phone
        : 'Phone not set';
    final email = _user?.email?.isNotEmpty == true
        ? _user!.email!
        : 'No email added';
    final shopName = _user?.shopName?.isNotEmpty == true
        ? _user!.shopName!
        : 'No shop specified';

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  ProfileAvatarWidget(
                    radius: 34,
                    photoUrl: _user?.photoUrl,
                    name: name,
                    showCameraBadge: true,
                    onTap: _changeProfilePhoto,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            CustomerTierBadge(
                              tier: _user?.tier ?? CustomerTier.silver,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _changeProfilePhoto,
                          borderRadius: BorderRadius.circular(6),
                          child: const Text(
                            'Change Profile Picture',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.award,
                              color: Color(0xFF2563EB),
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Wholesale Buyer Tier',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomerTierBadge(
                        tier: _user?.tier ?? CustomerTier.silver,
                        isCompact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Purchases on App:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₹${(_user?.totalPurchases ?? 0.0).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _user?.tier == CustomerTier.diamond
                                ? 1.0
                                : (_user?.tier == CustomerTier.gold
                                      ? ((_user?.totalPurchases ?? 0) / 200000)
                                            .clamp(0.0, 1.0)
                                      : ((_user?.totalPurchases ?? 0) / 50000)
                                            .clamp(0.0, 1.0)),
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _user?.tier == CustomerTier.diamond
                                  ? const Color(0xFF0284C7)
                                  : (_user?.tier == CustomerTier.gold
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF64748B)),
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '🥈 Silver\n₹0+',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: _user?.tier == CustomerTier.silver
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: _user?.tier == CustomerTier.silver
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '🥇 Gold\n₹50k+',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: _user?.tier == CustomerTier.gold
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: _user?.tier == CustomerTier.gold
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '💎 Diamond\n₹2L+',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight:
                                      _user?.tier == CustomerTier.diamond
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: _user?.tier == CustomerTier.diamond
                                      ? const Color(0xFF0284C7)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Account Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          _ProfileOption(
            icon: LucideIcons.atSign,
            title: 'Reseller username',
            subtitle: '@$username (Tap to change username)',
            onTap: _showEditUsernameDialog,
          ),
          _ProfileOption(
            icon: LucideIcons.user,
            title: 'Personal details',
            subtitle: 'Name: $name\nShop: $shopName\nEmail: $email',
            onTap: _showEditProfileDialog,
          ),
          _ProfileOption(
            icon: LucideIcons.mapPin,
            title: 'Pickup location',
            subtitle: 'Katargam Branch, Surat (Ready for pickup)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Primary pickup location: Katargam Branch, Surat',
                  ),
                ),
              );
            },
          ),
          _ProfileOption(
            icon: LucideIcons.receiptText,
            title: 'Order history',
            subtitle: 'View your cloud-synced orders and receipts',
            onTap: () {
              final uid = _user?.id ?? FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerOrdersScreen(userId: uid),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _ProfileOption(
            icon: LucideIcons.helpCircle,
            title: 'Help & support',
            subtitle: 'Contact wholesale support team: support@goodwin.com',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Support available 24/7 at support@goodwin.com',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


class ProfileOption extends StatelessWidget {
  const ProfileOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2563EB)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(
          LucideIcons.chevronRight,
          size: 14,
          color: Color(0xFF94A3B8),
        ),
        onTap: onTap,
      ),
    );
  }
}

typedef _ProfileOption = ProfileOption;

