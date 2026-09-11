import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class KskNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width, height;
  final BoxFit? fit;
  final double? borderRadius;

  const KskNetworkImage(
    this.imageUrl, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
  });

  @override
  State<KskNetworkImage> createState() => _KskNetworkImageState();
}

class _KskNetworkImageState extends State<KskNetworkImage> {
  @override
  Widget build(BuildContext context) {
    final double radius = widget.borderRadius ?? 12.0;

    if (widget.imageUrl.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child:
            const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
      );
    }

    // 1. URL Cleanup & Cloud CDN Optimization
    String cleanUrl = widget.imageUrl.trim();
    String finalUrl = cleanUrl;

    // 2. High-Performance Progressive Image Loader
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: finalUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit ?? BoxFit.contain,
        memCacheWidth: (widget.width != null &&
                widget.width! > 0 &&
                widget.width! != double.infinity)
            ? (widget.width! * 2).toInt()
            : 800,
        placeholder: (context, url) {
          return _buildShimmer(radius);
        },
        fadeOutDuration: const Duration(milliseconds: 200),
        fadeInDuration: const Duration(milliseconds: 400),
        errorWidget: (context, url, error) => SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Icon(Icons.broken_image_outlined,
              color: Colors.grey, size: 20),
        ),
      ),
    );
  }

  Widget _buildShimmer(double radius) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade100,
      highlightColor: Colors.white,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
