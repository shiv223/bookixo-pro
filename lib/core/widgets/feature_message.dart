import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_tokens.dart';

/// Scrollable empty/error content, including accessible retry feedback.
class FeatureMessage extends StatelessWidget {
  const FeatureMessage({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppTokens.homeInset),
    children: [
      Text(message, style: Theme.of(context).textTheme.bodyLarge),
      if (onRetry != null) ...[
        const SizedBox(height: AppTokens.gap),
        FilledButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
      ],
    ],
  );
}
