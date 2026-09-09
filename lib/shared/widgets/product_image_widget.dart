import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    final src = imageSrc.trim();
    Widget imageContent;

    if (src.isEmpty) {
      imageContent = _buildPlaceholder();
    } else if (src.startsWith('data:image')) {
      try {
        final commaIndex = src.indexOf(',');
        final base64Str = commaIndex != -1
            ? src.substring(commaIndex + 1)
            : src;
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
    } else if (src.startsWith('assets/')) {
      imageContent = Image.asset(
        src,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    } else if (kIsWeb) {
      // On Web, Image.network uses browser native image loading, bypassing CORS restrictions
      // that cause CachedNetworkImage to fail.
      imageContent = Image.network(
        src,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingSkeleton();
        },
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    } else {
      imageContent = CachedNetworkImage(
        imageUrl: src,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => _buildLoadingSkeleton(),
        errorWidget: (context, url, error) => Image.network(
          src,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => _buildPlaceholder(),
        ),
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
