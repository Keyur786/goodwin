import 'package:flutter/material.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';

/// Full-screen zoomable photo gallery dialog
class FullScreenImageViewerDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String productName;

  const FullScreenImageViewerDialog({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.productName = '',
  });

  @override
  State<FullScreenImageViewerDialog> createState() =>
      _FullScreenImageViewerDialogState();
}

class _FullScreenImageViewerDialogState
    extends State<FullScreenImageViewerDialog> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Top Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.productName.isNotEmpty)
                          Text(
                            widget.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (widget.images.length > 1)
                          Text(
                            'Photo ${_currentIndex + 1} of ${widget.images.length}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Main Interactive Zoomable Image Showcase
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (idx) {
                      setState(() => _currentIndex = idx);
                    },
                    itemBuilder: (ctx, i) {
                      return InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Center(
                          child: ProductImageWidget(
                            imageSrc: widget.images[i],
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                  if (widget.images.length > 1 && _currentIndex > 0)
                    Positioned(
                      left: 12,
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  if (widget.images.length > 1 &&
                      _currentIndex < widget.images.length - 1)
                    Positioned(
                      right: 12,
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Thumbnail Strip (for multiple photos)
            if (widget.images.length > 1)
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final isSelected = _currentIndex == i;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0F766E)
                                : Colors.white24,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ProductImageWidget(
                          imageSrc: widget.images[i],
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Bottom helper caption
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Pinch to zoom • Swipe to browse photos',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
