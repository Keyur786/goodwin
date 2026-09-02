import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Helper widget to render cached URLs, base64 data URIs, and asset images with loading skeletons
class ProductImageWidget extends StatelessWidget {
  final String imageSrc;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProductImageWidget({
    super.key,
    required this.imageSrc,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageContent;

    if (imageSrc.isEmpty) {
      imageContent = _buildPlaceholder();
    } else if (imageSrc.startsWith('data:image')) {
      try {
        final commaIndex = imageSrc.indexOf(',');
        final base64Str = commaIndex != -1
            ? imageSrc.substring(commaIndex + 1)
            : imageSrc;
        final bytes = base64Decode(base64Str);
        imageContent = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => _buildPlaceholder(),
        );
      } catch (_) {
        imageContent = _buildPlaceholder();
      }
    } else if (imageSrc.startsWith('assets/')) {
      imageContent = Image.asset(
        imageSrc,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    } else {
      imageContent = CachedNetworkImage(
        imageUrl: imageSrc,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => _buildLoadingSkeleton(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageContent);
    }
    return imageContent;
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          LucideIcons.image,
          color: Color(0xFFCBD5E1),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          LucideIcons.package,
          color: Color(0xFF94A3B8),
          size: 24,
        ),
      ),
    );
  }
}
