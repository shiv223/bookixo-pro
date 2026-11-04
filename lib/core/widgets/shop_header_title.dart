import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shop_context/presentation/selected_shop_provider.dart';
import '../localization/app_strings.dart';

/// Uppercase letters/digits only; punctuation separates words. Graphemes keep
/// accented letters intact. Missing or punctuation-only names have no suffix.
String shopAbbreviation(String? name) {
  final words = RegExp(
    r'[\p{L}\p{N}][\p{L}\p{M}\p{N}]*',
    unicode: true,
  ).allMatches(name ?? '').map((match) => match.group(0) ?? '').toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    return words.single.toUpperCase().characters.take(4).toString();
  }
  return words.map((word) => word.characters.first.toUpperCase()).join();
}

/// Appends only the validated selected salon, never a cached primary-shop name.
class ShopHeaderTitle extends ConsumerWidget {
  const ShopHeaderTitle({required this.title, this.style, super.key});

  final String title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abbreviation = shopAbbreviation(
      ref.watch(selectedShopProvider)?.name,
    );
    return Text(
      AppStrings.shopHeaderTitle(title, abbreviation),
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
