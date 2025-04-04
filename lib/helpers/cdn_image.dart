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
    finalSize = (size * scale).toInt();

    List<int> validValues = [
      // Powers of two
      16, 32, 64, 128, 256, 512, 1024, 2048, 4096,
      // Other valid sizes
      20, 22, 24, 28, 40, 44, 48, 56, 60, 80, 96, 100,
      160, 240, 300, 320, 480, 600, 640, 1280, 1536, 3072,
    ];

    validValues.sort();

    // Search for closest valid size

    int closest = validValues.first;
    int minDiff = (finalSize - closest).abs();

    for (int num in validValues) {
      int diff = (finalSize - num).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = num;
      }
    }

    finalSize = closest;
  }

  final String url =
      "https://cdn.discordapp.com/$path${finalSize != null ? "?size=$finalSize" : ""}";

  return cache
      ? CachedNetworkImageProvider(
        url,
        maxWidth: finalSize,
        maxHeight: finalSize,
      )
      : NetworkImage(url);
}
