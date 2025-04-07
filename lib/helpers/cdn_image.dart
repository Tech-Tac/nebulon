import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

ImageProvider cdnImage(
  BuildContext context,
  String path, {
  double? size,
  bool cache = true,
}) {
  int? finalSize;
  if (size != null) {
    final double scale = MediaQuery.devicePixelRatioOf(context);
    int scaledSize = (size * scale).round();

    List<int> validSizes = [
      // Some powers of two
      16, 32, 64, 128, 256, 512, 1024, 2048, 4096,
      // Other valid sizes too (peak poetry)
      20, 22, 24, 28, 40, 44, 48, 56, 60, 80, 96, 100,
      160, 240, 300, 320, 480, 600, 640, 1280, 1536, 3072,
    ];

    // Search for closest valid size, but prefer larger sizes
    int closest = validSizes.reduce((a, b) {
      int diffA = (a - scaledSize).abs();
      int diffB = (b - scaledSize).abs();
      if (diffA == diffB) return a > b ? a : b;
      return diffA < diffB ? a : b;
    });

    finalSize = closest;
  }

  Uri uri = Uri.parse(path);
  if (!uri.hasAuthority) {
    uri = uri.replace(scheme: "https", host: "cdn.discordapp.com");
  }
  if (finalSize != null) {
    uri = uri.replace(
      queryParameters: {...uri.queryParameters, "size": finalSize.toString()},
    );
  }

  final String url = uri.toString();

  return cache
      ? CachedNetworkImageProvider(
        url,
        maxWidth: finalSize,
        maxHeight: finalSize,
      )
      : NetworkImage(url);
}
