import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/recipe.dart';
import '../../providers.dart';

/// Renders a recipe's picture with v1.1 precedence: local file first, then
/// the imported network image, then a placeholder icon (spec §4.5).
class RecipeImage extends ConsumerWidget {
  final Recipe recipe;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  const RecipeImage({
    super.key,
    required this.recipe,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget placeholder() => SizedBox(
        width: width,
        height: height,
        child: Center(child: Icon(Icons.restaurant, size: iconSize)));

    final localPath = recipe.localImagePath;
    if (localPath != null) {
      return Image.file(
        ref.watch(imageStoreProvider).resolve(localPath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }
    if (recipe.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: recipe.imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorWidget: (_, _, _) => placeholder(),
      );
    }
    return placeholder();
  }
}
