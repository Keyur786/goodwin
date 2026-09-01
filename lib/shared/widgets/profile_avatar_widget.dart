import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:goodwin/core/constants/app_constants.dart';
import 'package:goodwin/shared/widgets/photo_option_button.dart';

class ProfileAvatarWidget extends StatelessWidget {
  const ProfileAvatarWidget({
    super.key,
    required this.radius,
    this.photoUrl,
    required this.name,
    this.showCameraBadge = false,
    this.onTap,
  });

  final double radius;
  final String? photoUrl;
  final String name;
  final bool showCameraBadge;
  final VoidCallback? onTap;

  String _getInitials(String inputName) {
    final trimmed = inputName.trim();
    if (trimmed.isEmpty) return 'GW';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final second = parts[1].isNotEmpty ? parts[1][0] : '';
      return (first + second).toUpperCase();
    } else if (trimmed.length >= 2) {
      return trimmed.substring(0, 2).toUpperCase();
    } else {
      return trimmed.substring(0, 1).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;
    final initials = _getInitials(name);

    Widget imageWidget;
    if (hasPhoto) {
      final url = photoUrl!.trim();
      if (url.startsWith('data:image')) {
        try {
          final base64Data = url.split(',').last;
          final bytes = base64Decode(base64Data);
          imageWidget = Image.memory(
            bytes,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          );
        } catch (_) {
          imageWidget = _buildFallback(initials);
        }
      } else {
        imageWidget = CachedNetworkImage(
          imageUrl: url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          errorWidget: (context, error, stackTrace) =>
              _buildFallback(initials),
        );
      }
    } else {
      imageWidget = _buildFallback(initials);
    }

    final avatarContent = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF115E59)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withAlpha(40),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(child: imageWidget),
        ),
        if (showCameraBadge)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatarContent,
      );
    }
    return avatarContent;
  }

  Widget _buildFallback(String initials) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

Future<void> showProfilePhotoPickerSheet({
  required BuildContext context,
  required void Function(String? photoUrl) onPhotoSelected,
  String? currentPhotoUrl,
}) async {
  final picker = ImagePicker();

  Future<void> pickFromSource(ImageSource source) async {
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        onPhotoSelected(base64String);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Profile Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a photo from your camera, gallery, or select a preset avatar.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: PhotoOptionButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFF0F766E),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await pickFromSource(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PhotoOptionButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: const Color(0xFF2563EB),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await pickFromSource(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Preset Avatars',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kPresetAvatars.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final avatarUrl = kPresetAvatars[index];
                    final isSelected = currentPhotoUrl == avatarUrl;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onPhotoSelected(avatarUrl);
                      },
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0F766E)
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 150),
                            errorWidget: (context, error, stackTrace) =>
                                const CircleAvatar(
                                  radius: 27,
                                  child: Icon(Icons.person),
                                ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Remove Profile Picture',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onPhotoSelected(null);
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
